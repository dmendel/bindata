require 'bindata/framework'
require 'bindata/io'
require 'bindata/lazy'
require 'bindata/name'
require 'bindata/offset'
require 'bindata/params'
require 'bindata/registry'
require 'bindata/sanitize'

module BinData
  # This is the abstract base class for all data objects.
  class Base
    extend AcceptedParametersPlugin
    include Framework
    include CheckOrAdjustOffsetPlugin
    include RegisterNamePlugin

    class << self
      # Instantiates this class and reads from +io+, returning the newly
      # created data object.
      def read(io, *args)
        obj = self.new(*args)
        obj.read(io)
        obj
      end

      # The arg processor for this class.
      def arg_processor(name = nil)
        if name
          @arg_processor = "#{name}_arg_processor".gsub(/(?:^|_)(.)/) { $1.upcase }.to_sym
        elsif @arg_processor.is_a? Symbol
          @arg_processor = BinData::const_get(@arg_processor).new
        elsif @arg_processor.nil?
          @arg_processor = superclass.arg_processor
        else
          @arg_processor
        end
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
        define_singleton_method(:inherited) do |subclass|
          RegisteredClasses.register(subclass.name, subclass)
          register_subclasses
          super(subclass)
        end
      end

      private :unregister_self, :register_subclasses
    end

    # Register all subclasses of this class.
    register_subclasses

    # Set the initial arg processor.
    arg_processor :base

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
    #
    def initialize(*args)
      value, @params, @parent = extract_args(args)

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

    # Resets the internal state to that of a newly created object.
    def clear
      initialize_instance
    end

    # Reads data into this data object.
    def read(io)
      io = BinData::IO::Read.new(io) unless BinData::IO::Read === io

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
      io = BinData::IO::Write.new(io) unless BinData::IO::Write === io

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
    alias_method :base_respond_to?, :respond_to? #:nodoc:

    #---------------
    private

    def extract_args(args)
      self.class.arg_processor.extract_args(self.class, args)
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

    def binary_string(str)
      str.to_s.dup.force_encoding(Encoding::BINARY)
    end
  end

  # ArgProcessors process the arguments passed to BinData::Base.new into
  # the form required to initialise the BinData object.
  #
  # Any passed parameters are sanitized so the BinData object doesn't
  # need to perform error checking on the parameters.
  class BaseArgProcessor
    @@empty_hash = Hash.new.freeze

    # Takes the arguments passed to BinData::Base.new and
    # extracts [value, sanitized_parameters, parent].
    def extract_args(obj_class, obj_args)
      value, params, parent = separate_args(obj_class, obj_args)
      sanitized_params = SanitizedParameters.sanitize(params, obj_class)

      [value, sanitized_params, parent]
    end

    # Separates the arguments passed to BinData::Base.new into
    # [value, parameters, parent].  Called by #extract_args.
    def separate_args(obj_class, obj_args)
      args = obj_args.dup
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

    # Performs sanity checks on the given parameters.
    # This method converts the parameters to the form expected
    # by the data object.
    def sanitize_parameters!(obj_class, obj_params) 
    end
  end
end
