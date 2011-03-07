require 'bindata/dsl'
require 'bindata/sanitize'
require 'bindata/struct'

module BinData
  # Extracts args for Records.
  #
  # Foo.new(:bar => "baz) is ambiguous as to whether :bar is a value or parameter.
  #
  # BaseArgExtractor always assumes :bar is parameter.  This extractor correctly
  # identifies it as value or parameter.
  class RecordArgExtractor
    class << self
      def extract(the_class, the_args)
        value, parameters, parent = BaseArgExtractor.extract(the_class, the_args)

        if parameters_is_value?(the_class, value, parameters)
          value = parameters
          parameters = {}
        end

        [value, parameters, parent]
      end

      def parameters_is_value?(the_class, value, parameters)
        if value.nil? and parameters.length > 0
          field_names_in_parameters?(the_class, parameters)
        else
          false
        end
      end

      def field_names_in_parameters?(the_class, parameters)
        field_names = the_class.fields.field_names
        param_keys = parameters.keys

        (field_names & param_keys).length > 0
      end
    end
  end

  # A Record is a declarative wrapper around Struct.
  #
  #    require 'bindata'
  #
  #    class SomeDataType < BinData::Record
  #      hide :a
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
  class Record < BinData::Struct
    include DSLMixin

    unregister_self
    dsl_parser :struct

    class << self

      def arg_extractor
        RecordArgExtractor
      end

      def sanitize_parameters!(params) #:nodoc:
        params.merge!(dsl_params)

        super(params)

        define_field_accessors(params[:fields].fields)
      end

      # Defines accessor methods to avoid the overhead of going through
      # Struct#method_missing.  This is purely a speed optimisation.
      # Removing this method will not have any effect on correctness.
      def define_field_accessors(fields) #:nodoc:
        unless method_defined?(:bindata_defined_accessors_for_fields?)
          fields.each_with_index do |field, i|
            name = field.name_as_sym
            if name
              define_field_accessors_for(name, i)
            end
          end

          define_method(:bindata_defined_accessors_for_fields?) { true }
        end
      end

      def define_field_accessors_for(name, index)
        define_method(name) do
          instantiate_obj_at(index) unless @field_objs[index]
          @field_objs[index]
        end
        define_method(name.to_s + "=") do |*vals|
          instantiate_obj_at(index) unless @field_objs[index]
          @field_objs[index].assign(*vals)
        end
      end
    end
  end
end
