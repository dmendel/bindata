require 'bindata/io'
require 'bindata/lazy'
require 'bindata/params'
require 'bindata/registry'
require 'bindata/sanitize'
require 'stringio'

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
  # [<tt>:readwrite</tt>]     Deprecated. An alias for :onlyif.
  # [<tt>:onlyif</tt>]        Used to indicate a data object is optional.
  #                           if false, calls to #read or #write will not
  #                           perform any I/O, #num_bytes will return 0 and
  #                           #snapshot will return nil.  Default is true.
  # [<tt>:check_offset</tt>]  Raise an error if the current IO offset doesn't
  #                           meet this criteria.  A boolean return indicates
  #                           success or failure.  Any other return is compared
  #                           to the current offset.  The variable +offset+
  #                           is made available to any lambda assigned to
  #                           this parameter.  This parameter is only checked
  #                           before reading.
  # [<tt>:adjust_offset</tt>] Ensures that the current IO offset is at this
  #                           position before reading.  This is like
  #                           <tt>:check_offset</tt>, except that it will
  #                           adjust the IO offset instead of raising an error.
  class Base

    class << self
      extend Parameters

      # Define methods for:
      #   bindata_mandatory_parameters
      #   bindata_optional_parameters
      #   bindata_default_parameters
      #   bindata_mutually_exclusive_parameters

      define_x_parameters(:bindata_mandatory, []) do |array, args|
        args.each { |arg| array << arg.to_sym }
        array.uniq!
      end

      define_x_parameters(:bindata_optional, []) do |array, args|
        args.each { |arg| array << arg.to_sym }
        array.uniq!
      end

      define_x_parameters(:bindata_default, {}) do |hash, args|
        params = args.length > 0 ? args[0] : {}
        hash.merge!(params)
      end

      define_x_parameters(:bindata_mutually_exclusive, []) do |array, args|
        array << [args[0].to_sym, args[1].to_sym]
      end

      # Returns a list of internal parameters that are accepted by this object
      def internal_parameters
        (bindata_mandatory_parameters + bindata_optional_parameters +
         bindata_default_parameters.keys).uniq
      end

      # Ensures that +params+ is of the form expected by #initialize.
      def sanitize_parameters!(sanitizer, params)
        # replace :readwrite with :onlyif
        if params.has_key?(:readwrite)
          warn ":readwrite is deprecated. Replacing with :onlyif"
          params[:onlyif] = params.delete(:readwrite)
        end

        # add default parameters
        bindata_default_parameters.each do |k,v|
          params[k] = v unless params.has_key?(k)
        end

        # ensure mandatory parameters exist
        bindata_mandatory_parameters.each do |prm|
          if not params.has_key?(prm)
            raise ArgumentError, "parameter ':#{prm}' must be specified " +
                                 "in #{self}"
          end
        end

        # ensure mutual exclusion
        bindata_mutually_exclusive_parameters.each do |param1, param2|
          if params.has_key?(param1) and params.has_key?(param2)
            raise ArgumentError, "params #{param1} and #{param2} " +
                                 "are mutually exclusive"
          end
        end
      end

      # Can this data object self reference itself?
      def recursive?
        false
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
    end

    # Define the parameters we use in this class.
    bindata_optional_parameters :check_offset, :adjust_offset
    bindata_default_parameters :onlyif => true
    bindata_mutually_exclusive_parameters :check_offset, :adjust_offset

    # Creates a new data object.
    #
    # +params+ is a hash containing symbol keys.  Some params may
    # reference callable objects (methods or procs).  +parent+ is the
    # parent data object (e.g. struct, array, choice) this object resides
    # under.
    def initialize(params = {}, parent = nil)
      @params = Sanitizer.sanitize(self.class, params)
      @parent = parent
    end

    # The parent data object.
    attr_accessor :parent

    # Returns all the custom parameters supplied to this data object.
    def parameters
      @params.extra_parameters
    end

    # Reads data into this data object by calling #do_read then #done_read.
    def read(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      do_read(io)
      done_read
      self
    end

    # Reads the value for this data from +io+.
    def do_read(io)
      raise ArgumentError, "io must be a BinData::IO" unless BinData::IO === io

      clear
      check_offset(io)

      if eval_param(:onlyif)
        _do_read(io)
      end
    end

    # Writes the value for this data to +io+ by calling #do_write.
    def write(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      do_write(io)
      io.flush
      self
    end


    # Writes the value for this data to +io+.
    def do_write(io)
      raise ArgumentError, "io must be a BinData::IO" unless BinData::IO === io

      if eval_param(:onlyif)
        _do_write(io)
      end
    end

    # Returns the number of bytes it will take to write this data by calling
    # #do_num_bytes.
    def num_bytes(what = nil)
      num = do_num_bytes(what)
      num.ceil
    end

    # Returns the number of bytes it will take to write this data.
    def do_num_bytes(what = nil)
      if eval_param(:onlyif)
        _do_num_bytes(what)
      else
        0
      end
    end

    # Returns a snapshot of this data object.
    # Returns nil if :onlyif is false
    def snapshot
      if eval_param(:onlyif)
        _snapshot
      else
        nil
      end
    end

    # Returns the string representation of this data object.
    def to_s
      io = StringIO.new
      write(io)
      io.rewind
      io.read
    end

    # Return a human readable representation of this object.
    def inspect
      snapshot.inspect
    end

    # Returns the object this object represents.
    def obj
      self
    end

    #---------------
    private

    # Returns the value of the evaluated parameter.  +key+ references a
    # parameter from the +params+ hash used when creating the data object.
    # +values+ contains data that may be accessed when evaluating +key+.
    # Returns nil if +key+ does not refer to any parameter.
    def eval_param(key, values = nil)
      LazyEvaluator.eval(no_eval_param(key), self, values)
    end

    # Returns the parameter from the +params+ hash referenced by +key+.
    # Use this method if you are sure the parameter is not to be evaluated.
    # You most likely want #eval_param.
    def no_eval_param(key)
      @params.internal_parameters[key]
    end

    # Returns whether +key+ exists in the +params+ hash used when creating
    # this data object.
    def has_param?(key)
      @params.internal_parameters.has_key?(key)
    end

    # Checks that the current offset of +io+ is as expected.  This should
    # be called from #do_read before performing the reading.
    def check_offset(io)
      if has_param?(:check_offset)
        actual_offset = io.offset
        expected = eval_param(:check_offset, :offset => actual_offset)

        if not expected
          raise ValidityError, "offset not as expected"
        elsif actual_offset != expected and expected != true
          raise ValidityError, "offset is '#{actual_offset}' but " +
                               "expected '#{expected}'"
        end
      elsif has_param?(:adjust_offset)
        actual_offset = io.offset
        expected = eval_param(:adjust_offset)
        if actual_offset != expected
          begin
            seek = expected - actual_offset
            io.seekbytes(seek)
            warn "adjusting stream position by #{seek} bytes" if $VERBOSE
          rescue
            # could not seek so raise an error
            raise ValidityError, "offset is '#{actual_offset}' but " +
                                 "couldn't seek to expected '#{expected}'"
          end
        end
      end
    end

    ###########################################################################
    # To be implemented by subclasses

    # Resets the internal state to that of a newly created object.
    def clear
      raise NotImplementedError
    end

    # Returns true if the object has not been changed since creation.
    def clear?(*args)
      raise NotImplementedError
    end

    # Returns whether this data object contains a single value.  Single
    # value data objects respond to <tt>#value</tt> and <tt>#value=</tt>.
    def single_value?
      raise NotImplementedError
    end

    # To be called after calling #do_read.
    def done_read
      raise NotImplementedError
    end

    # Reads the data for this data object from +io+.
    def _do_read(io)
      raise NotImplementedError
    end

    # Writes the value for this data to +io+.
    def _do_write(io)
      raise NotImplementedError
    end

    # Returns the number of bytes it will take to write this data.
    def _do_num_bytes
      raise NotImplementedError
    end

    # Returns a snapshot of this data object.
    def _snapshot
      raise NotImplementedError
    end

    # Set visibility requirements of methods to implement
    public :clear, :clear?, :single_value?, :done_read
    private :_do_read, :_do_write, :_do_num_bytes, :_snapshot

    # End To be implemented by subclasses
    ###########################################################################
  end
end
