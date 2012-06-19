require 'bindata/io'
require 'bindata/lazy'
require 'bindata/offset'
require 'bindata/params'
require 'bindata/registry'
require 'bindata/sanitize'

module BinData
  # Error raised when unexpected results occur when reading data from IO.
  class ValidityError < StandardError ; end

  # ArgExtractors take the arguments passed to BinData::Base.new and
  # separates them into [value, parameters, parent].
  class BaseArgExtractor
    @@empty_hash = Hash.new.freeze

    def self.extract(the_class, the_args)
      args = the_args.dup
      value = parameters = parent = nil

      if args.length > 1 and args.last.is_a? BinData::Base
        parent = args.pop
      end

      if args.length > 0 and args.last.is_a? Hash
        parameters = args.pop
      end

      if args.length > 0
        value = args.pop
      end

      parameters ||= @@empty_hash

      return [value, parameters, parent]
    end
  end

  # This is the abstract base class for all data objects.
  class Base
    include AcceptedParametersMixin
    include CheckOrAdjustOffsetMixin

    class << self

      # Instantiates this class and reads from +io+, returning the newly
      # created data object.
      def read(io)
        obj = self.new
        obj.read(io)
        obj
      end

      # The arg extractor for this class.
      def arg_extractor
        BaseArgExtractor
      end

      # The name of this class as used by Records, Arrays etc.
      def bindata_name
        RegisteredClasses.underscore_name(self.name)
      end

      # Call this method if this class is abstract and not to be used.
      def unregister_self
        RegisteredClasses.unregister(name)
      end

      # Registers all subclasses of this class for use
      def register_subclasses #:nodoc:
        class << self
          define_method(:inherited) do |subclass|
            RegisteredClasses.register(subclass.name, subclass)
            register_subclasses
          end
        end
      end

      private :unregister_self, :register_subclasses
    end

    # Register all subclasses of this class.
    register_subclasses

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

      @params = SanitizedParameters.sanitize(parameters, self.class)
      @parent = parent

      add_methods_for_check_or_adjust_offset

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
      obj = clone
      obj.parent = parent if parent
      obj.initialize_instance
      obj.assign(value) if value

      obj
    end

    # Returns the result of evaluating the parameter identified by +key+.
    #
    # +overrides+ is an optional +parameters+ like hash that allow the
    # parameters given at object construction to be overridden.
    #
    # Returns nil if +key+ does not refer to any parameter.
    def eval_parameter(key, overrides = nil)
      value = get_parameter(key)
      if value.is_a?(Symbol) or value.respond_to?(:arity)
        lazy_evaluator.lazy_eval(value, overrides)
      else
        value
      end
    end

    # Returns a lazy evaluator for this object.
    def lazy_evaluator #:nodoc:
      @lazy ||= LazyEvaluator.new(self)
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

    # Override and delegate =~ as it is defined in Object.
    def =~(other)
      snapshot =~ other
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

    # A version of +respond_to?+ used by the lazy evaluator.  It doesn't
    # reinvoke the evaluator so as to avoid infinite evaluation loops.
    def safe_respond_to?(symbol, include_private = false) #:nodoc:
      respond_to?(symbol, include_private)
    end
    alias_method :orig_respond_to?, :respond_to? #:nodoc:

    #---------------
    private

    def extract_args(the_args)
      self.class.arg_extractor.extract(self.class, the_args)
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

    ###########################################################################
    # To be implemented by subclasses

    # Performs sanity checks on the given parameters.  This method converts
    # the parameters to the form expected by this data object.
    def self.sanitize_parameters!(parameters) #:nodoc:
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
