require 'bindata/lazy'
require 'bindata/registry'

module BinData
  # Error raised when unexpected results occur when reading data from IO.
  class ValidityError < StandardError ; end

  # This is the abstract base class for all data objects.
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # [<tt>:readwrite</tt>]     If false, calls to #read or #write will
  #                           not perform any I/O.  Default is true.
  # [<tt>:check_offset</tt>]  Raise an error if the current IO offset doesn't
  #                           meet this criteria.  A boolean return indicates
  #                           success or failure.  Any other return is compared
  #                           to the current offset.  The variable +offset+
  #                           is made available to any lambda assigned to
  #                           this parameter.  This parameter is only checked
  #                           before reading.
  class Base
    class << self
      # Returns the mandatory parameters used by this class.  Any given args
      # are appended to the parameters list.  The parameters for a class will
      # include the parameters of its ancestors.
      def mandatory_parameters(*args)
        unless defined? @mandatory_parameters
          @mandatory_parameters = []
          ancestors[1..-1].each do |parent|
            if parent.respond_to?(:mandatory_parameters)
              @mandatory_parameters.concat(parent.mandatory_parameters)
            end
          end
        end
        if not args.empty?
          args.each { |arg| @mandatory_parameters << arg.to_sym }
          @mandatory_parameters.uniq!
        end
        @mandatory_parameters
      end
      alias_method :mandatory_parameter, :mandatory_parameters

      # Returns the optional parameters used by this class.  Any given args
      # are appended to the parameters list.  The parameters for a class will
      # include the parameters of its ancestors.
      def optional_parameters(*args)
        unless defined? @optional_parameters
          @optional_parameters = []
          ancestors[1..-1].each do |parent|
            if parent.respond_to?(:optional_parameters)
              @optional_parameters.concat(parent.optional_parameters)
            end
          end
        end
        if not args.empty?
          args.each { |arg| @optional_parameters << arg.to_sym }
          @optional_parameters.uniq!
        end
        @optional_parameters
      end
      alias_method :optional_parameter, :optional_parameters

      # Returns both the mandatory and optional parameters used by this class.
      def parameters
        # warn about deprecated method - remove before releasing 1.0
        warn "warning: #parameters is deprecated."
        (mandatory_parameters + optional_parameters).uniq
      end

      # Instantiates this class and reads from +io+.  For single value objects
      # just the value is returned, otherwise the newly created data object is
      # returned.
      def read(io)
        data = self.new
        data.read(io)
        data.single_value? ? data.value : data
      end

      # Registers the mapping of +name+ to +klass+.
      def register(name, klass)
        Registry.instance.register(name, klass)
      end
      private :register

      # Returns the class matching a previously registered +name+.
      def lookup(name)
        klass = Registry.instance.lookup(name)
        if klass.nil?
          # lookup failed so attempt endian lookup
          if self.respond_to?(:endian) and self.endian != nil
            name = name.to_s
            if /^u?int\d\d?$/ =~ name
              new_name = name + ((self.endian == :little) ? "le" : "be")
              klass = Registry.instance.lookup(new_name)
            elsif ["float", "double"].include?(name)
              new_name = name + ((self.endian == :little) ? "_le" : "_be")
              klass = Registry.instance.lookup(new_name)
            end
          end
        end
        klass
      end
    end

    # Define the parameters we use in this class.
    optional_parameters :check_offset, :readwrite

    # Creates a new data object.
    #
    # +params+ is a hash containing symbol keys.  Some params may
    # reference callable objects (methods or procs).  +env+ is the
    # environment that these callable objects are evaluated in.
    def initialize(params = {}, env = nil)
      # all known parameters
      mandatory = self.class.mandatory_parameters
      optional = self.class.optional_parameters

      # default :readwrite param to true if unspecified
      if not params.has_key?(:readwrite)
        params = params.dup
        params[:readwrite] = true
      end

      # ensure mandatory parameters exist
      mandatory.each do |prm|
        if not params.has_key?(prm)
          raise ArgumentError, "parameter ':#{prm}' must be specified " +
                               "in #{self}"
        end
      end

      # partition parameters into known and extra parameters
      @params = {}
      extra   = {}
      params.each do |k,v|
        k = k.to_sym
        raise ArgumentError, "parameter :#{k} is nil in #{self}" if v.nil?
        if mandatory.include?(k) or optional.include?(k)
          @params[k] = v.freeze
        else
          extra[k] = v.freeze
        end
      end

      # set up the environment
      @env             = env || LazyEvalEnv.new
      @env.params      = extra
      @env.data_object = self
    end

    # Returns the class matching a previously registered +name+.
    def klass_lookup(name)
      @cache ||= {}
      klass = @cache[name]
      if klass.nil?
        klass = self.class.lookup(name)
        if klass.nil? and @env.parent_data_object != nil
          # lookup failed so retry in the context of the parent data object
          klass = @env.parent_data_object.klass_lookup(name)
        end
        @cache[name] = klass
      end
      klass
    end

    # Returns a list of parameters that are accepted by this object
    def accepted_parameters
      (self.class.mandatory_parameters + self.class.optional_parameters).uniq
    end

    # Reads data into this bin object by calling #do_read then #done_read.
    def read(io)
      # remove previous method to prevent warnings
      class << io
        undef_method(:bindata_mark) if method_defined?(:bindata_mark)
      end

      # remember the current position in the IO object
      io.instance_eval "def bindata_mark; #{io.pos}; end"

      do_read(io)
      done_read
      self
    end

    # Reads the value for this data from +io+.
    def do_read(io)
      clear
      check_offset(io)
      _do_read(io) if eval_param(:readwrite) != false
    end

    # Writes the value for this data to +io+.
    def write(io)
      _write(io) if eval_param(:readwrite) != false
    end

    # Returns the number of bytes it will take to write this data.
    def num_bytes(what = nil)
      (eval_param(:readwrite) != false) ? _num_bytes(what) : 0
    end

    # Returns whether this data object contains a single value.  Single
    # value data objects respond to <tt>#value</tt> and <tt>#value=</tt>.
    def single_value?
      respond_to? :value
    end

    # Return a human readable representation of this object.
    def inspect
      snapshot.inspect
    end

    #---------------
    private

    # Creates a new LazyEvalEnv for use by a child data object.
    def create_env
      LazyEvalEnv.new(@env)
    end

    # Returns the value of the evaluated parameter.  +key+ references a
    # parameter from the +params+ hash used when creating the data object.
    # +values+ contains data that may be accessed when evaluating +key+.
    # Returns nil if +key+ does not refer to any parameter.
    def eval_param(key, values = nil)
      @env.lazy_eval(@params[key], values)
    end

    # Returns the parameter from the +params+ hash referenced by +key+.
    # Use this method if you are sure the parameter is not to be evaluated.
    # You most likely want #eval_param.
    def param(key)
      @params[key]
    end

    # Returns whether +key+ exists in the +params+ hash used when creating
    # this data object.
    def has_param?(key)
      @params.has_key?(key.to_sym)
    end

    # Raise an error if +param1+ and +param2+ are both given as params.
    def ensure_mutual_exclusion(param1, param2)
      if has_param?(param1) and has_param?(param2)
        raise ArgumentError, "params #{param1} and #{param2} " +
                             "are mutually exclusive"
      end
    end

    # Checks that the current offset of +io+ is as expected.  This should
    # be called from #do_read before performing the reading.
    def check_offset(io)
      if has_param?(:check_offset)
        actual_offset = io.pos - io.bindata_mark
        expected = eval_param(:check_offset, :offset => actual_offset)

        if not expected
          raise ValidityError, "offset not as expected"
        elsif actual_offset != expected and expected != true
          raise ValidityError, "offset is '#{actual_offset}' but " +
                               "expected '#{expected}'"
        end
      end
    end

    # To be implemented by subclasses

    # Resets the internal state to that of a newly created object.
    def clear
      raise NotImplementedError
    end

    # Reads the data for this data object from +io+.
    def _do_read(io)
      raise NotImplementedError
    end

    # To be called after calling #do_read.
    def done_read
      raise NotImplementedError
    end

    # Writes the value for this data to +io+.
    def _write(io)
      raise NotImplementedError
    end

    # Returns the number of bytes it will take to write this data.
    def _num_bytes
      raise NotImplementedError
    end

    # Returns a snapshot of this data object.
    def snapshot
      raise NotImplementedError
    end

    # Returns a list of the names of all fields accessible through this
    # object.
    def field_names
      raise NotImplementedError
    end

    # Set visibility requirements of methods to implement
    public :clear, :done_read, :snapshot, :field_names
    private :_do_read, :_write, :_num_bytes

    # End To be implemented by subclasses
  end
end
