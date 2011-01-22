require 'bindata/io'
require 'bindata/lazy'
require 'bindata/params'
require 'bindata/registry'
require 'bindata/sanitize'

module BinData
  # Error raised when unexpected results occur when reading data from IO.
  class ValidityError < StandardError ; end

  # This is the abstract base class for all data objects.
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These parameters are:
  #
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
    include AcceptedParametersMixin

    optional_parameters :check_offset, :adjust_offset
    optional_parameter  :onlyif                            # Used by Struct
    mutually_exclusive_parameters :check_offset, :adjust_offset

    class << self

      # Instantiates this class and reads from +io+, returning the newly
      # created data object.
      def read(io)
        self.new.tap { |obj| obj.read(io) }
      end

      # The name of this class as used by Records, Arrays etc.
      def bindata_name
        RegisteredClasses.underscore_name(self.name)
      end

      # Registers this class for use.
      def register_self
        register_class(self)
      end

      # Registers all subclasses of this class for use
      def register_subclasses
        class << self
          define_method(:inherited) do |subclass|
            register_class(subclass)
          end
        end
      end

      def register_class(class_to_register) #:nodoc:
        RegisteredClasses.register(class_to_register.name, class_to_register)
      end

      private :register_self, :register_subclasses, :register_class
    end

    # Creates a new data object.
    #
    # Args are optional, but if present, must be in the following order.
    #
    # +value+ is a value that is +assign+ed immediately after initialization.
    #
    # +parameters+ is a hash containing symbol keys.  Some parameters may
    # reference callable objects (methods or procs).
    #
    # +parent+ is the parent data object (e.g. struct, array, choice) this
    # object resides under.
    def initialize(*args)
      value, parameters, parent = extract_args(args)
      @params = Sanitizer.sanitize(parameters, self.class)
      prepare_for_read_with_offset

      @parent = parent if parent
      initialize_shared_instance
      initialize_instance
      assign(value) if value
    end

    attr_accessor :parent
    protected :parent=

    # Creates a new data object based on this instance.
    #
    # All parameters will be be duplicated.  Use this method 
    # when creating multiple objects with the same parameters.
    def new(value = nil, parent = nil)
      clone.tap do |obj|
        obj.parent = parent if parent
        obj.initialize_instance
        obj.assign(value) if value
      end
    end

    # Returns the result of evaluating the parameter identified by +key+.
    #
    # +overrides+ is an optional +parameters+ like hash that allow the
    # parameters given at object construction to be overridden.
    #
    # Returns nil if +key+ does not refer to any parameter.
    def eval_parameter(key, overrides = {})
      LazyEvaluator.eval(self, get_parameter(key), overrides)
    end

    # Returns the parameter referenced by +key+.
    # Use this method if you are sure the parameter is not to be evaluated.
    # You most likely want #eval_parameter.
    def get_parameter(key)
      @params[key]
    end

    # Returns whether +key+ exists in the +parameters+ hash.
    def has_parameter?(key)
      @params.has_parameter?(key)
    end

    # Reads data into this data object.
    def read(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      @in_read = true
      clear
      do_read(io)
      @in_read = false

      self
    end

    #:nodoc:
    attr_reader :in_read
    protected   :in_read

    # Returns if this object is currently being read.  This is used
    # internally by BasePrimitive.
    def reading? #:nodoc:
      furthest_ancestor.in_read
    end
    protected :reading?

    # Writes the value for this data object to +io+.
    def write(io)
      io = BinData::IO.new(io) unless BinData::IO === io

      do_write(io)
      io.flush
      self
    end

    # Returns the number of bytes it will take to write this data object.
    def num_bytes
      do_num_bytes.ceil
    end

    # Returns the string representation of this data object.
    def to_binary_s
      io = BinData::IO.create_string_io
      write(io)
      io.rewind
      io.read
    end

    # Return a human readable representation of this data object.
    def inspect
      snapshot.inspect
    end

    # Return a string representing this data object.
    def to_s
      snapshot.to_s
    end

    # Work with Ruby's pretty-printer library.
    def pretty_print(pp) #:nodoc:
      pp.pp(snapshot)
    end

    # Returns a user friendly name of this object for debugging purposes.
    def debug_name
      if @parent
        @parent.debug_name_of(self)
      else
        "obj"
      end
    end

    # Returns the offset of this object wrt to its most distant ancestor.
    def offset
      if @parent
        @parent.offset + @parent.offset_of(self)
      else
        0
      end
    end

    # Returns the offset of this object wrt to its parent.
    def rel_offset
      if @parent
        @parent.offset_of(self)
      else
        0
      end
    end

    def ==(other) #:nodoc:
      # double dispatch
      other == snapshot
    end

    #---------------
    private

    def extract_args(the_args)
      args = the_args.dup
      value = parameters = parent = nil

      if args.length > 1 and args.last.is_a? BinData::Base
        parent = args.pop
      end

      if args.length > 0 and args.last.respond_to?(:keys)
        parameters = args.pop
      end

      if args.length > 0
        value = args.pop
      end

      parameters ||= {}

      return [value, parameters, parent]
    end

    def furthest_ancestor
      if parent.nil?
        self
      else
        an = parent
        an = an.parent while an.parent
        an
      end
    end

    def prepare_for_read_with_offset
      if has_parameter?(:check_offset)
        class << self
          alias_method :do_read_without_check_offset, :do_read
          alias_method :do_read, :do_read_with_check_offset
          public :do_read
        end
      end
      if has_parameter?(:adjust_offset)
        class << self
          alias_method :do_read_without_adjust_offset, :do_read
          alias_method :do_read, :do_read_with_adjust_offset
          public :do_read
        end
      end
    end

    def do_read_with_check_offset(io) #:nodoc:
      check_offset(io)
      do_read_without_check_offset(io)
    end

    def do_read_with_adjust_offset(io) #:nodoc:
      adjust_offset(io)
      do_read_without_adjust_offset(io)
    end

    def check_offset(io)
      actual_offset = io.offset
      expected = eval_parameter(:check_offset, :offset => actual_offset)

      if not expected
        raise ValidityError, "offset not as expected for #{debug_name}"
      elsif actual_offset != expected and expected != true
        raise ValidityError,
              "offset is '#{actual_offset}' but " +
              "expected '#{expected}' for #{debug_name}"
      end
    end

    def adjust_offset(io)
      actual_offset = io.offset
      expected = eval_parameter(:adjust_offset)
      if actual_offset != expected
        begin
          seek = expected - actual_offset
          io.seekbytes(seek)
          warn "adjusting stream position by #{seek} bytes" if $VERBOSE
        rescue
          raise ValidityError,
                "offset is '#{actual_offset}' but couldn't seek to " +
                "expected '#{expected}' for #{debug_name}"
        end
      end
    end

    ###########################################################################
    # To be implemented by subclasses

    # Performs sanity checks on the given parameters.  This method converts
    # the parameters to the form expected by this data object.
    def self.sanitize_parameters!(parameters, sanitizer) #:nodoc:
    end

    # Initializes the state of the object.  All instance variables that
    # are used by the object must be initialized here.
    def initialize_instance
    end

    # Initialises state that is shared by objects with the same parameters.
    #
    # This should only be used when optimising for performance.  Instance
    # variables set here, and changes to the singleton class will be shared
    # between all objects that are initialized with the same parameters.
    # This method is called only once for a particular set of parameters.
    def initialize_shared_instance
    end

    # Resets the internal state to that of a newly created object.
    def clear
      raise NotImplementedError
    end

    # Returns true if the object has not been changed since creation.
    def clear?
      raise NotImplementedError
    end

    # Assigns the value of +val+ to this data object.  Note that +val+ must
    # always be deep copied to ensure no aliasing problems can occur.
    def assign(val)
      raise NotImplementedError
    end

    # Returns a snapshot of this data object.
    def snapshot
      raise NotImplementedError
    end

    # Returns the debug name of +child+.  This only needs to be implemented
    # by objects that contain child objects.
    def debug_name_of(child) #:nodoc:
      debug_name
    end

    # Returns the offset of +child+.  This only needs to be implemented
    # by objects that contain child objects.
    def offset_of(child) #:nodoc:
      0
    end

    # Reads the data for this data object from +io+.
    def do_read(io) #:nodoc:
      raise NotImplementedError
    end

    # Writes the value for this data to +io+.
    def do_write(io) #:nodoc:
      raise NotImplementedError
    end

    # Returns the number of bytes it will take to write this data.
    def do_num_bytes #:nodoc:
      raise NotImplementedError
    end

    # Set visibility requirements of methods to implement
    public :clear, :clear?, :assign, :snapshot, :debug_name_of, :offset_of
    protected :initialize_instance, :initialize_shared_instance
    protected :do_read, :do_write, :do_num_bytes

    # End To be implemented by subclasses
    ###########################################################################
  end
end
