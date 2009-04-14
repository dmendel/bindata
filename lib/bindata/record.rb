require 'bindata/params'
require 'bindata/registry'
require 'bindata/struct'

module BinData
  # A Record is a declarative wrapper around Struct.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::Record
  #      int8  :x
  #      int8  :y
  #      int8  :z
  #    end
  #
  #    class SomeDataType < BinData::Record
  #      hide 'a'
  #
  #      int32le :a
  #      int16le :b
  #      tuple   :s
  #    end
  #
  #    obj = SomeDataType.new
  #    obj.field_names   =># ["b", "s"]
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
  #                      type.  Name is the name of this field.  Params is an
  #                      optional hash of parameters to pass to this field
  #                      when instantiating it.
  # <tt>:hide</tt>::     A list of the names of fields that are to be hidden
  #                      from the outside world.  Hidden fields don't appear
  #                      in #snapshot or #field_names but are still accessible
  #                      by name.
  # <tt>:endian</tt>::   Either :little or :big.  This specifies the default
  #                      endian of any numerics in this struct, or in any
  #                      nested data objects.
  class Record < BinData::Struct

    class << self

      def inherited(subclass) #:nodoc:
        # Register the names of all subclasses of this class.
        register(subclass.name, subclass)
      end

      def recursive?
        # A Record can self reference itself.
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

      def hide(*args)
        @hide ||= []
        @hide.concat(args.collect { |name| name.to_s })
        @hide
      end

      def method_missing(symbol, *args)
        name, params = args

        type = symbol
        name = name.to_s
        params ||= {}

        ensure_type_exists(type)
        ensure_valid_name(name)

        append_field(type, name, params)
      end

      def sanitize_parameters!(sanitizer, params)
        merge_endian!(params)
        merge_fields!(params)
        merge_hide!(params)
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
        @fields ||= []
        @fields.each do |t, n, p|
          if n == name
            raise SyntaxError, "duplicate field '#{name}' in #{self}", caller(4)
          end
        end
        if self.instance_methods.include?(name)
          raise NameError.new("", name),
                "field '#{name}' shadows an existing method", caller(2)
        end
        if self::RESERVED.include?(name)
          raise NameError.new("", name),
                "field '#{name}' is a reserved name", caller(2)
        end
      end

      def append_field(type, name, params)
        @fields ||= []
        @fields.push([type, name, params])
      end

      def merge_endian!(params)
        endian = params[:endian] || self.endian
        params[:endian] = endian unless endian.nil?
      end

      def merge_fields!(params)
        @fields ||= []
        fields = params[:fields] || @fields || []
        params[:fields] = fields
      end

      def merge_hide!(params)
        hide = params[:hide] || self.hide
        params[:hide] = hide
      end
    end
  end

  class MultiValue < Record
    class << self
      def inherited(subclass) #:nodoc:
        warn "BinData::MultiValue is deprecated.  Replacing with BinData::Record"
        super
      end
    end
  end
end
