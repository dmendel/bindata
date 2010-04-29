require 'bindata/base_primitive'
require 'bindata/dsl'
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
    include DSLMixin

    register_subclasses
    dsl_parser :multiple_fields, :optional_fieldnames, :sanitize_fields

    class << self
      def sanitize_parameters!(params, sanitizer) #:nodoc:
        params[:struct_params] = sanitizer.create_sanitized_params(to_struct_params, BinData::Struct)
      end
    end

    mandatory_parameter :struct_params

    def initialize(parameters = {}, parent = nil)
      super

      @struct = BinData::Struct.new(get_parameter(:struct_params), self)
    end

    def method_missing(symbol, *args, &block) #:nodoc:
      @struct.__send__(symbol, *args, &block)
    end

    def debug_name_of(child) #:nodoc:
      debug_name + "-internal-"
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
