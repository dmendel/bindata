require 'bindata/dsl'
require 'bindata/sanitize'
require 'bindata/struct'

module BinData
  # A Record is a declarative wrapper around Struct.
  #
  #    require 'bindata'
  #
  #    class SomeDataType < BinData::Record
  #      hide 'a'
  #
  #      int32le :a
  #      int16le :b
  #      struct  :s do
  #        int8  :x
  #        int8  :y
  #        int8  :z
  #      end
  #    end
  #
  #    obj = SomeDataType.new
  #    obj.field_names   =># ["b", "s"]
  #    obj.s.field_names =># ["x", "y", "z"]
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
    include DSLMixin

    register_subclasses
    dsl_parser :multiple_fields, :optional_fieldnames, :sanitize_fields, :hidden_fields

    class << self
      def sanitize_parameters!(params, sanitizer) #:nodoc:
        params[:fields] = fields
        params[:endian] = endian unless endian.nil?
        params[:hide]   = hide   unless hide.empty?

        super(params, sanitizer)

        define_field_accessors(params[:fields].fields)
      end

      # Defines accessor methods to avoid the overhead of going through
      # Struct#method_missing.  This is purely a speed optimisation.
      # Removing this method will not have any effect on correctness.
      def define_field_accessors(fields) #:nodoc:
        unless method_defined?(:bindata_defined_accessors_for_fields?)
          fields.each_with_index do |field, i|
            name = field.name
            if name
              define_method(name.to_sym) do
                instantiate_obj_at(i) unless @field_objs[i]
                @field_objs[i]
              end
              define_method((name + "=").to_sym) do |*vals|
                instantiate_obj_at(i) unless @field_objs[i]
                @field_objs[i].assign(*vals)
              end
            end
          end

          define_method(:bindata_defined_accessors_for_fields?) { true }
        end
      end
    end
  end
end
