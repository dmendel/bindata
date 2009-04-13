require 'bindata/params'
require 'bindata/registry'
require 'bindata/single'
require 'bindata/struct'

module BinData
  # A SingleValue is a declarative way to define a new BinData data type.
  # The data type must contain a single value only.  For new data types
  # that contain multiple values see BinData::MultiValue.
  #
  # To define a new data type, set fields as if for MultiValue and add a
  # #get and #set method to extract / convert the data between the fields
  # and the #value of the object.
  #
  #    require 'bindata'
  #
  #    class PascalString < BinData::SingleValue
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
  #    class Uint24be < BinData::SingleValue
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
  # SingleValue objects accept all the parameters that BinData::Single do.
  #
  class SingleValue < Single

    class << self

      def inherited(subclass) #:nodoc:
        # Register the names of all subclasses of this class.
        register(subclass.name, subclass)
      end

      def recursive?
        # A SingleValue can possibly self reference itself.
        true
      end

      AcceptedParameters.define_accessors(self, :custom, :mandatory, :default)

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

        ensure_type_exists(type)
        ensure_valid_name(name) unless name.nil?

        append_field(type, name, params)
      end

      def sanitize_parameters!(sanitizer, params)
        struct_params = {}
        struct_params[:fields] = fields
        struct_params[:endian] = endian unless endian.nil?
        
        params[:struct_params] = struct_params

        AcceptedParameters.get(self, :custom).sanitize_parameters!(sanitizer, params)

        super(sanitizer, params)
      end

      #-------------
      private

      def ensure_type_exists(type)
        unless RegisteredClasses.is_registered?(type, endian)
          raise TypeError, "unknown type '#{type}' for #{self}", caller(2)
        end
      end

      def ensure_valid_name(name)
        fields.each do |t, n, p|
          if n == name
            raise SyntaxError, "duplicate field '#{name}' in #{self}", caller(4)
          end
        end
        if self.instance_methods.include?(name)
          raise NameError.new("", name),
                "field '#{name}' shadows an existing method", caller(2)
        end
      end

      def append_field(type, name, params)
        fields.push([type, name, params])
      end

      def fields
        @fields ||= []
      end
    end

    bindata_mandatory_parameter :struct_params

    def initialize(params = {}, parent = nil)
      super(params, parent)

      @struct = BinData::Struct.new(no_eval_param(:struct_params), self)
    end

    def method_missing(symbol, *args, &block)
      if @struct.respond_to?(symbol)
        @struct.__send__(symbol, *args, &block)
      else
        super
      end
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
