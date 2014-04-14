require 'bindata/dsl'
require 'bindata/struct'

module BinData
  # A Record is a declarative wrapper around Struct.
  #
  # See +Struct+ for more info.
  class Record < BinData::Struct
    include DSLMixin

    unregister_self
    dsl_parser :struct

    class << self

      def arg_extractor
        MultiFieldArgExtractor
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
