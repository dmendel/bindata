require 'bindata/params'
require 'bindata/registry'
require 'bindata/struct'
require 'set'

module BinData
  # A MultiValue is a declarative wrapper around Struct.
  #
  #    require 'bindata'
  #
  #    class Tuple < BinData::MultiValue
  #      int8  :x
  #      int8  :y
  #      int8  :z
  #    end
  #
  #    class SomeDataType < BinData::MultiValue
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
  class MultiValue < BinData::Struct

    class << self
      extend Parameters

      def inherited(subclass) #:nodoc:
        # Register the names of all subclasses of this class.
        register(subclass.name, subclass)
      end

      # A MultiValue can self reference itself.
      def recursive?
        true
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

      # Returns the names of any hidden fields in this struct.  Any given args
      # are appended to the hidden list.
      def hide(*args)
        @hide ||= []
        @hide.concat(args.collect { |name| name.to_s })
        @hide
      end

      # Sets the mandatory parameters used by this class.
      def mandatory_parameters(*args) ; end

      define_parameters(:mandatory, Set.new) do |set, args|
        set.merge(args.collect { |a| a.to_sym })
      end

      # Sets the default parameters used by this class.
      def default_parameters(params = {}); end

      define_parameters(:default, {}) do |hash, args|
        params = args[0]
        hash.merge!(params)
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
        merge_default_custom_parameters!(params)
        ensure_mandatory_custom_parameters_exist(params)

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
            raise SyntaxError, "duplicate field '#{name}' in #{self}", caller(2)
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
        fields = params[:fields] || @fields || []
        params[:fields] = fields
      end

      def merge_hide!(params)
        hide = params[:hide] || self.hide
        params[:hide] = hide
      end

      def merge_default_custom_parameters!(params)
        default_parameters.each do |k,v|
          params[k] = v unless params.has_key?(k)
        end
      end

      def ensure_mandatory_custom_parameters_exist(params)
        mandatory_parameters.each do |prm|
          unless params.has_key?(prm)
            raise ArgumentError, "parameter ':#{prm}' must be specified " +
                                 "in #{self}"
          end
        end
      end
    end
  end
end
