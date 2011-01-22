require 'bindata/dsl'
require 'bindata/sanitize'
require 'bindata/struct'

module BinData
  class RecordArgExtractor
    def self.extract(the_class, the_args)
      value, parameters, parent = BaseArgExtractor.extract(the_class, the_args)

      if value.nil? and parameters.length > 0
        if field_names_in_parameters(the_class, parameters).length > 0
          value = parameters
          parameters = nil
        end
      end

      [value, parameters, parent]
    end

    def self.field_names_in_parameters(the_class, parameters)
      field_names = the_class.fields.field_names.collect { |k| k.to_s }
      param_keys = parameters.keys.collect { |k| k.to_s }

      (field_names & param_keys)
    end
  end

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

      def arg_extractor
        RecordArgExtractor
      end

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
            if field.name
              define_field_accessors_for(field.name, i)
            end
          end

          define_method(:bindata_defined_accessors_for_fields?) { true }
        end
      end

      def define_field_accessors_for(name, index)
        define_method(name.to_sym) do
          instantiate_obj_at(index) unless @field_objs[index]
          @field_objs[index]
        end
        define_method((name + "=").to_sym) do |*vals|
          instantiate_obj_at(index) unless @field_objs[index]
          @field_objs[index].assign(*vals)
        end
      end
    end
  end
end
