require 'bindata/registry'

module BinData

  # When a BinData object is instantiated, it can be supplied parameters to
  # determine its behaviour.  These parameters must be sanitized to ensure
  # their values are valid.  When instantiating many objects, such as an array
  # of records, there is much duplicated validation.
  #
  # The purpose of the sanitizing code is to eliminate the duplicated
  # validation.
  #
  # SanitizedParameters is a hash-like collection of parameters.  Its purpose
  # it to recursively sanitize the parameters of an entire BinData object chain
  # at a single time.
  class SanitizedParameters

    def initialize(parameters, the_class)
      @all_sanitized = false
      @the_class = the_class

      @parameters = {}
      parameters.each { |key, value| @parameters[key.to_sym] = value }

      ensure_no_nil_values
    end

    def length
      @parameters.size
    end
    alias_method :size, :length

    def [](key)
      @parameters[key]
    end

    def []=(key, value)
      @parameters[key] = value unless @all_sanitized
    end

    def has_parameter?(key)
      @parameters.has_key?(key)
    end

    def needs_sanitizing?(key)
      has_parameter?(key) and not self[key].is_a?(SanitizedParameter)
    end

    def all_sanitized?
      @all_sanitized
    end

    def sanitize!(sanitizer)
      unless @all_sanitized
        merge_default_parameters!

        @the_class.sanitize_parameters!(self, sanitizer)

        ensure_mandatory_parameters_exist
        ensure_mutual_exclusion_of_parameters

        @all_sanitized = true
      end
    end

    def move_unknown_parameters_to(dest)
      unless @all_sanitized
        unused_keys = @parameters.keys - @the_class.accepted_parameters.all
        unused_keys.each do |key|
          dest[key] = @parameters.delete(key)
        end
      end
    end

    def warn_replacement_parameter(bad_key, suggested_key)
      if has_parameter?(bad_key)
        warn ":#{bad_key} is not used with #{@the_class}.  " +
        "You probably want to change this to :#{suggested_key}"
      end
    end

    #---------------
    private

    def ensure_no_nil_values
      @parameters.each do |key, value|
        if value.nil?
          raise ArgumentError,
                "parameter '#{key}' has nil value in #{@the_class}"
        end
      end
    end

    def merge_default_parameters!
      @the_class.default_parameters.each do |key, value|
        self[key] ||= value
      end
    end

    def ensure_mandatory_parameters_exist
      @the_class.mandatory_parameters.each do |key|
        unless has_parameter?(key)
          raise ArgumentError,
                  "parameter '#{key}' must be specified in #{@the_class}"
        end
      end
    end

    def ensure_mutual_exclusion_of_parameters
      return if length < 2

      @the_class.mutually_exclusive_parameters.each do |key1, key2|
        if has_parameter?(key1) and has_parameter?(key2)
          raise ArgumentError, "params '#{key1}' and '#{key2}' " +
                               "are mutually exclusive in #{@the_class}"
        end
      end
    end

  end
  #----------------------------------------------------------------------------

  # The Sanitizer sanitizes the parameters that are passed when creating a
  # BinData object.  Sanitizing consists of checking for mandatory, optional
  # and default parameters and ensuring the values of known parameters are
  # valid.
  class Sanitizer

    class << self
      # Sanitize +params+ for +the_class+.
      # Returns sanitized parameters.
      def sanitize(params, the_class)
        if params.is_a?(SanitizedParameters) and params.all_sanitized?
          params
        else
          sanitizer = self.new
          sanitizer.create_sanitized_params(params, the_class)
        end
      end
    end

    def initialize
      @endian = nil
    end

    def create_sanitized_params(params, the_class)
      sanitized_params = as_sanitized_params(params, the_class)
      sanitized_params.sanitize!(self)

      sanitized_params
    end

    def create_sanitized_endian(endian)
      SanitizedEndian.new(endian)
    end

    def create_sanitized_choices(choices)
      SanitizedChoices.new(self, choices)
    end

    def create_sanitized_fields(fields = nil)
      new_fields = SanitizedFields.new(self)
      new_fields.copy_fields(fields) if fields
      new_fields
    end

    def create_sanitized_object_prototype(obj_type, obj_params, endian = nil)
      SanitizedPrototype.new(self, obj_type, obj_params, endian)
    end

    def with_endian(endian, &block)
      if endian != nil
        saved_endian = @endian
        @endian = endian.is_a?(SanitizedEndian) ? endian.endian : endian
        yield
        @endian = saved_endian
      else
        yield
      end
    end

    def lookup_class(type)
      RegisteredClasses.lookup(type, @endian)
    end

    #---------------
    private

    def as_sanitized_params(params, the_class)
      if SanitizedParameters === params
        params
      else
        SanitizedParameters.new(params || {}, the_class)
      end
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedParameter; end

  class SanitizedPrototype < SanitizedParameter
    def initialize(sanitizer, obj_type, obj_params, endian)
      sanitizer.with_endian(endian) do
        @obj_class = sanitizer.lookup_class(obj_type)
        @obj_params = sanitizer.create_sanitized_params(obj_params, @obj_class)
      end
    end

    def instantiate(parent = nil)
      @obj_class.new(@obj_params, parent)
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedField < SanitizedParameter
    def initialize(sanitizer, name, field_type, field_params, endian)
      @name = (name != nil and name != "") ? name.to_s : nil
      @prototype = sanitizer.create_sanitized_object_prototype(field_type, field_params, endian)
    end
    attr_reader :name

    def instantiate(parent = nil)
      @prototype.instantiate(parent)
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedFields < SanitizedParameter
    def initialize(sanitizer)
      @sanitizer = sanitizer
      @fields = []
    end
    attr_reader :fields

    def add_field(type, name, params, endian)
      @fields << SanitizedField.new(@sanitizer, name, type, params, endian)
    end

    def [](idx)
      @fields[idx]
    end

    def empty?
      @fields.empty?
    end

    def field_names
      @fields.collect { |field| field.name }
    end

    def copy_fields(other)
      @fields.concat(other.fields)
    end
  end
  #----------------------------------------------------------------------------

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
  #----------------------------------------------------------------------------

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
