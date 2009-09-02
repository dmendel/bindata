require 'bindata/base_primitive'
require 'bindata/struct'

module BinData
  # A Primitive is a declarative way to define a new BinData data type.
  # The data type must contain a primitive value only, i.e numbers or strings.
  # For new data types that contain multiple values see BinData::Record.
  #
  # To define a new data type, set fields as if for Record and add a
  # #get and #set method to extract / convert the data between the fields
  # and the #value of the object.
  #
  #    require 'bindata'
  #
  #    class PascalString < BinData::Primitive
  #      uint8  :len,  :value => lambda { data.length }
  #      string :data, :read_length => :len
  #    
  #      def get
  #        self.data
  #      end
  #    
  #      def set(v)
  #        self.data = v
  #      end
  #    end
  #
  #    ps = PascalString.new(:initial_value => "hello")
  #    ps.to_binary_s #=> "\005hello"
  #    ps.read("\003abcde")
  #    ps.value #=> "abc"
  #
  #    # Unsigned 24 bit big endian integer
  #    class Uint24be < BinData::Primitive
  #      uint8 :byte1
  #      uint8 :byte2
  #      uint8 :byte3
  #
  #      def get
  #        (self.byte1 << 16) | (self.byte2 << 8) | self.byte3
  #      end
  #
  #      def set(v)
  #        v = 0 if v < 0
  #        v = 0xffffff if v > 0xffffff
  #
  #        self.byte1 = (v >> 16) & 0xff
  #        self.byte2 = (v >>  8) & 0xff
  #        self.byte3 =  v        & 0xff
  #      end
  #    end
  #
  #    u24 = Uint24be.new
  #    u24.read("\x12\x34\x56")
  #    "0x%x" % u24.value #=> 0x123456
  #
  # == Parameters
  #
  # Primitive objects accept all the parameters that BinData::BasePrimitive do.
  #
  class Primitive < BasePrimitive

    class << self

      def inherited(subclass) #:nodoc:
        # Register the names of all subclasses of this class.
        register(subclass.name, subclass)
      end

      def endian(endian = nil)
        @endian ||= nil
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError, "unknown value for endian '#{endian}'", caller(1)
        end
        @endian
      end

      def method_missing(symbol, *args)
        name, params = args

        type = symbol
        name = name.to_s
        params ||= {}

        append_field(type, name, params)
      end

      def sanitize_parameters!(params, sanitizer)
        struct_params = {}
        struct_params[:fields] = fields
        struct_params[:endian] = endian unless endian.nil?
        
        params[:struct_params] = struct_params
      end

      #-------------
      private

      def fields
        unless defined? @fields
          sanitizer = Sanitizer.new
          @fields = sanitizer.create_sanitized_fields(endian)
        end
        @fields
      end

      def append_field(type, name, params)
        ensure_valid_name(name)

        fields.add_field(type, name, params)
      rescue TypeError
        raise TypeError, "unknown type '#{type}' for #{self}", caller(2)
      end

      def ensure_valid_name(name)
        if fields.field_names.include?(name)
          raise SyntaxError, "duplicate field '#{name}' in #{self}", caller(3)
        end
        if self.instance_methods.collect { |meth| meth.to_s }.include?(name)
          raise NameError.new("", name),
                "field '#{name}' shadows an existing method", caller(3)
        end
      end
    end

    mandatory_parameter :struct_params

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @struct = BinData::Struct.new(get_parameter(:struct_params), self)
    end

    def method_missing(symbol, *args, &block)
      @struct.__send__(symbol, *args, &block)
    end

    def debug_name_of(child)
      debug_name + "-internal-"
    end

    def offset_of(child)
      offset
    end

    #---------------
    private

    def sensible_default
      get
    end

    def read_and_return_value(io)
      @struct.read(io)
      get
    end

    def value_to_binary_string(val)
      set(val)
      @struct.to_binary_s
    end

    ###########################################################################
    # To be implemented by subclasses

    # Extracts the value for this data object from the fields of the
    # internal struct.
    def get
      raise NotImplementedError
    end

    # Sets the fields of the internal struct to represent +v+.
    def set(v)
      raise NotImplementedError
    end

    # To be implemented by subclasses
    ###########################################################################
  end
end
