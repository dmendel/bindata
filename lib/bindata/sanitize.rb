require 'bindata/registry'
require 'forwardable'

module BinData

  # A BinData object accepts arbitrary parameters.  This class identifies
  # parameters that have been sanitized.
  class SanitizedParameters
    extend Forwardable

    def initialize(the_class, params)
      @parameters = {}

      params.each do |k,v|
        k = k.to_sym
        if v.nil?
          raise ArgumentError, "parameter :#{k} has nil value in #{the_class}"
        end

        @parameters[k] = v
      end

      @all_sanitized = false
    end

    attr_reader :parameters

    def_delegators :@parameters, :[], :[]=, :has_key?, :include?, :keys, :each, :delete, :collect

    def needs_sanitizing?(k)
#      p "testing #{k} #{self[k].class if has_key?(k)}"
      has_key?(k) and not self[k].is_a?(SanitizedParameter)
    end

    def all_sanitized?
      @all_sanitized
    end

    def done_sanitizing
      @all_sanitized = true
    end
  end

  # The Sanitizer sanitizes the parameters that are passed when creating a
  # BinData object.  Sanitizing consists of checking for mandatory, optional
  # and default parameters and ensuring the values of known parameters are
  # valid.
  class Sanitizer

    class << self
      # Sanitize +params+ for +the_class+.
      # Returns sanitized parameters.
      def sanitize(the_class, params)
        if params.is_a?(SanitizedParameters) and params.all_sanitized?
          params
        else
          sanitizer = self.new
          sanitizer.create_sanitized_params(the_class, params)
        end
      end
    end

    def initialize
      @endian = nil
    end

    def create_sanitized_params(the_class, params)
      params ||= {}

      sparams = SanitizedParameters.new(the_class, params)
      # TODO: call base default
      the_class.sanitize_parameters!(self, sparams)
      # TODO: call base mandatory and mutex
      sparams.done_sanitizing

      sparams
    end

    def create_sanitized_endian(endian)
      SanitizedEndian.new(endian)
    end

    def create_sanitized_choices(choices)
      SanitizedChoices.new(self, choices)
    end

    def create_sanitized_fields(endian)
      SanitizedFields.new(self, endian)
    end

    def create_sanitized_object_prototype(obj_class, obj_params)
      SanitizedPrototype.new(self, obj_class, obj_params)
    end

    # Executes the given block with +endian+ set as the current endian.
    def with_endian(endian, &block)
      if endian != nil
        saved_endian = @endian
        @endian = endian
        yield
        @endian = saved_endian
      else
        yield
      end
    end

    def lookup_class(type)
      registered_class = RegisteredClasses.lookup(type, @endian)
      if registered_class.nil?
        raise TypeError, "unknown type '#{type}'"
      end
      registered_class
    end

    #---------------
    private

  end

  class SanitizedParameter
  end

  class SanitizedPrototype < SanitizedParameter
    def initialize(sanitizer, obj_type, obj_params)
      @obj_class = sanitizer.lookup_class(obj_type)
      @obj_params = sanitizer.create_sanitized_params(@obj_class, obj_params)
    end

    def instantiate(parent = nil)
      @obj_class.new(@obj_params, parent)
    end
  end

  class SanitizedField < SanitizedParameter
    def initialize(sanitizer, name, field_type, field_params)
      @name = name.to_s
      @prototype = sanitizer.create_sanitized_object_prototype(field_type, field_params)
    end
    attr_reader :name

    def instantiate(parent = nil)
      @prototype.instantiate(parent)
    end
  end

  class SanitizedFields < SanitizedParameter
    def initialize(sanitizer, endian)
      @sanitizer = sanitizer
      @endian = endian.is_a?(SanitizedEndian) ? endian.endian : endian
      @fields = []
    end

    def add_field(type, name, params)
      @sanitizer.with_endian(@endian) do
        @fields << SanitizedField.new(@sanitizer, name, type, params)
      end
    end

    def [](idx)
      @fields[idx]
    end

    def field_names
      @fields.collect { |f| f.name }
    end
  end

  class SanitizedChoices < SanitizedParameter
    def initialize(sanitizer, choices)
      @choices = {}
      choices.each_pair do |key, val|
        type, param = val
        prototype = sanitizer.create_sanitized_object_prototype(type, param)
        @choices[key] = prototype
      end
    end

    def [](key)
      @choices[key]
    end
  end

  class SanitizedValue < SanitizedParameter
    def initialize(value)
      @value = value
    end

    attr_reader :value
  end

  class SanitizedEndian < SanitizedParameter
    def initialize(endian)
      unless [:little, :big].include?(endian)
        raise ArgumentError, "unknown value for endian '#{endian}'"
      end

      @endian = endian
    end

    attr_reader :endian
  end
end
