require 'bindata/single'
require 'bindata/struct'

module BinData
  # A Struct is an ordered collection of named data objects.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::Struct
  #      int8  :x
  #      int8  :y
  #      int8  :z
  #    end
  #
  #    class SomeStruct < BinData::Struct
  #      hide 'a'
  #
  #      int32le :a
  #      int16le :b
  #      tuple   nil
  #    end
  #
  #    obj = SomeStruct.new
  #    obj.field_names   =># ["b", "x", "y", "z"]
  #
  #
  # == Parameters
  #
  # Parameters may be provided at initialisation to control the behaviour of
  # an object.  These params are:
  #
  # <tt>:fields</tt>::   An array specifying the fields for this struct.
  #                      Each element of the array is of the form [type, name,
  #                      params].  Type is a symbol representing a registered
  #                      type.  Name is the name of this field.  Name may be
  #                      nil as in the example above.  Params is an optional
  #                      hash of parameters to pass to this field when
  #                      instantiating it.
  # <tt>:hide</tt>::     A list of the names of fields that are to be hidden
  #                      from the outside world.  Hidden fields don't appear
  #                      in #snapshot or #field_names but are still accessible
  #                      by name.
  class SingleValue < Single

    class << self
      # Register the names of all subclasses of this class.
      def inherited(subclass) #:nodoc:
        register(subclass.name, subclass)
      end

      # Returns or sets the endianess of numerics used in this stucture.
      # Endianess is applied to the fields of this structure.
      # Valid values are :little and :big.
      def endian(endian = nil)
        @endian ||= nil
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError, "unknown value for endian '#{endian}'"
        end
        @endian
      end

      # Returns all stored fields.  Should only be called by #sanitize_parameters
      def fields
        @fields || []
      end

      # Used to define fields for this structure.
      def method_missing(symbol, *args)
        name, params = args

        type = symbol
        name = (name.nil? or name == "") ? nil : name.to_s
        params ||= {}

        # note that fields are stored in an instance variable not a class var
        @fields ||= []

        # check that type is known
        if lookup(type, endian).nil?
          raise TypeError, "unknown type '#{type}' for #{self}", caller
        end

        # check that name is okay
        if name != nil
          # check for duplicate names
          @fields.each do |t, n, p|
            if n == name
              raise SyntaxError, "duplicate field '#{name}' in #{self}", caller
            end
          end

          # check that name doesn't shadow an existing method
          if self.instance_methods.include?(name)
            raise NameError.new("", name),
                  "field '#{name}' shadows an existing method", caller
          end
        end

        # remember this field.  These fields will be recalled upon creating
        # an instance of this class
        @fields.push([type, name, params])
      end

      # Returns a hash of cleaned +params+.  Cleaning means that param
      # values are converted to a desired format.
      def sanitize_parameters(params, endian = nil)
        params = params.dup

        # possibly override endian
        endian = self.endian || endian

        hash = {}
        hash[:fields] = self.fields

        unless endian.nil?
          hash[:endian] = endian
        end
        
        params[:struct_params] = hash

        super(params, endian)
      end
    end

    # These are the parameters used by this class.
    mandatory_parameter :struct_params

    def initialize(params = {}, env = nil)
      super(params, env)

      @struct = BinData::Struct.new(param(:struct_params), create_env)
    end

    def method_missing(symbol, *args, &block)
      if @struct.respond_to?(symbol)
        @struct.__send__(symbol, *args, &block)
      else
        super
      end
    end

    #---------------
    private

    def sensible_default
      get
    end

    def read_val(io)
      @struct.read(io)
      get
    end

    def val_to_str(val)
      set(val)
      @struct.to_s
    end

    ###########################################################################
    # To be implemented by subclasses

    def get
      raise NotImplementedError
    end

    def set(v)
      raise NotImplementedError
    end

    # To be implemented by subclasses
    ###########################################################################
  end
end
