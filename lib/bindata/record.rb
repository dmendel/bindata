require 'bindata/dsl'
require 'bindata/sanitize'
require 'bindata/struct'

module BinData
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
  #    obj.field_names   =># [:b, :s]
  #    obj.s.field_names =># [:x, :y, :z]
  #
  class Record < BinData::Struct
    include DSLMixin

    unregister_self
    dsl_parser    :struct
    arg_processor :record

    def initialize_shared_instance
      define_field_accessors
      super
    end

    #---------------
    private

    # Defines accessor methods to avoid the overhead of going through
    # Struct#method_missing.  This is purely a speed optimisation.
    # Removing this method will not affect correctness.
    def define_field_accessors
      get_parameter(:fields).each_with_index do |field, i|
        name = field.name_as_sym
        define_field_accessors_for(name, i) if name
      end
    end

    def define_field_accessors_for(name, index)
      self.class.send(:define_method, name) do
        instantiate_obj_at(index) unless @field_objs[index]
        @field_objs[index]
      end
      self.class.send(:define_method, name.to_s + "=") do |*vals|
        instantiate_obj_at(index) unless @field_objs[index]
        @field_objs[index].assign(*vals)
      end
    end
  end

  class RecordArgProcessor < StructArgProcessor
    include MultiFieldArgSeparator

    def sanitize_parameters!(obj_class, params)
      super(obj_class, params.merge!(obj_class.dsl_params))
    end
  end
end
