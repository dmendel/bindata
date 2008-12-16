require 'bindata/io'
require 'bindata/lazy'
require 'bindata/params'
require 'bindata/registry'
require 'bindata/sanitize'
require 'set'
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

      # Instantiates this class and reads from +io+.  For single value objects
      # just the value is returned, otherwise the newly created data object is
      # returned.
      def read(io)
        data = self.new
        data.read(io)
        data.single_value? ? data.value : data
      end

      # Can this data object self reference itself?
      def recursive?
        false
      end

      # Define methods for:
      #   bindata_mandatory_parameters
      #   bindata_optional_parameters
      #   bindata_default_parameters
      #   bindata_mutually_exclusive_parameters

      define_parameters(:bindata_mandatory, Set.new) do |set, args|
        set.merge(args.collect { |a| a.to_sym })
      end

      define_parameters(:bindata_optional, Set.new) do |set, args|
        set.merge(args.collect { |a| a.to_sym })
      end

      define_parameters(:bindata_default, {}) do |hash, args|
        params = args[0]
        hash.merge!(params)
      end

      define_parameters(:bindata_mutually_exclusive, Set.new) do |set, args|
        set.add([args[0].to_sym, args[1].to_sym])
      end

      # Returns a list of internal parameters that are accepted by this object
      def internal_parameters
        (bindata_mandatory_parameters + bindata_optional_parameters +
         bindata_default_parameters.keys)
      end

      def sanitize_parameters!(sanitizer, params)
        merge_default_parameters!(params)
        ensure_mandatory_parameters_exist(params)
        ensure_mutual_exclusion_of_parameters(params)
      end

      #-------------
      private

      def merge_default_parameters!(params)
        bindata_default_parameters.each do |k,v|
          params[k] = v unless params.has_key?(k)
        end
      end

      def ensure_mandatory_parameters_exist(params)
        bindata_mandatory_parameters.each do |prm|
          unless params.has_key?(prm)
            raise ArgumentError, "parameter ':#{prm}' must be specified " +
                                 "in #{self}"
          end
        end
      end

      def ensure_mutual_exclusion_of_parameters(params)
        bindata_mutually_exclusive_parameters.each do |param1, param2|
          if params.has_key?(param1) and params.has_key?(param2)
            raise ArgumentError, "params #{param1} and #{param2} " +
                                 "are mutually exclusive"
          end
        end
      end

      def register(name, class_to_register)
        RegisteredClasses.register(name, class_to_register)
      end
    end

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
    def custom_parameters
      @params.extra_parameters
    end

    # Reads data into this data object.
    def read(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      do_read(io)
      done_read
      self
    end

    def do_read(io)
      if eval_param(:onlyif)
        check_or_adjust_offset(io)
        clear
        _do_read(io)
      end
    end

    def done_read
      if eval_param(:onlyif)
        _done_read
      end
    end

    # Writes the value for this data to +io+ by calling #do_write.
    def write(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      do_write(io)
      io.flush
      self
    end

    def do_write(io)
      if eval_param(:onlyif)
        _do_write(io)
      end
    end

    # Returns the number of bytes it will take to write this data.
    def num_bytes(what = nil)
      num = do_num_bytes(what)
      num.ceil
    end

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

    def check_or_adjust_offset(io)
      if has_param?(:check_offset)
        check_offset(io)
      elsif has_param?(:adjust_offset)
        adjust_offset(io)
      end
    end

    def check_offset(io)
      actual_offset = io.offset
      expected = eval_param(:check_offset, :offset => actual_offset)

      if not expected
        raise ValidityError, "offset not as expected"
      elsif actual_offset != expected and expected != true
        raise ValidityError, "offset is '#{actual_offset}' but " +
                             "expected '#{expected}'"
      end
    end

    def adjust_offset(io)
      actual_offset = io.offset
      expected = eval_param(:adjust_offset)
      if actual_offset != expected
        begin
          seek = expected - actual_offset
          io.seekbytes(seek)
          warn "adjusting stream position by #{seek} bytes" if $VERBOSE
        rescue
          raise ValidityError, "offset is '#{actual_offset}' but " +
                               "couldn't seek to expected '#{expected}'"
        end
      end
    end

    ###########################################################################
    # Available to subclasses

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

    # Available to subclasses
    ###########################################################################

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

    # Reads the data for this data object from +io+.
    def _do_read(io)
      raise NotImplementedError
    end

    # Trigger function that is called after #do_read.
    def _done_read
      raise NotImplementedError
    end

    # Writes the value for this data to +io+.
    def _do_write(io)
      raise NotImplementedError
    end

    # Returns the number of bytes it will take to write this data.
    def _do_num_bytes(what)
      raise NotImplementedError
    end

    # Returns a snapshot of this data object.
    def _snapshot
      raise NotImplementedError
    end

    # Set visibility requirements of methods to implement
    public :clear, :clear?, :single_value?
    private :_do_read, :_done_read, :_do_write, :_do_num_bytes, :_snapshot

    # End To be implemented by subclasses
    ###########################################################################
  end
end
