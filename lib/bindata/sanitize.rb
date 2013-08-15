require 'bindata/registry'

module BinData

  # Subclasses of this are sanitized
  class SanitizedParameter; end

  class SanitizedPrototype < SanitizedParameter
    def initialize(obj_type, obj_params, endian)
      endian = endian.endian if endian.respond_to? :endian
      obj_params ||= {}

      if obj_type.is_a? Class
        @obj_class = obj_type
      else
        @obj_class  = RegisteredClasses.lookup(obj_type, endian)
      end
      @obj_params = SanitizedParameters.new(obj_params, @obj_class, endian)
    end

    def instantiate(value = nil, parent = nil)
      @factory ||= @obj_class.new(@obj_params)

      @factory.new(value, parent)
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedField < SanitizedParameter
    def initialize(name, field_type, field_params, endian)
      @name      = name
      @prototype = SanitizedPrototype.new(field_type, field_params, endian)
    end

    attr_reader :prototype

    def name_as_sym
      @name.nil? ? nil : @name.to_sym
    end

    def name
      @name
    end

    def instantiate(value = nil, parent = nil)
      @prototype.instantiate(value, parent)
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedFields < SanitizedParameter
    def initialize(endian)
      @fields = []
      @endian = endian
    end
    attr_reader :fields

    def add_field(type, name, params)
      name = nil if name == ""

      @fields << SanitizedField.new(name, type, params, @endian)
    end

    def [](idx)
      @fields[idx]
    end

    def empty?
      @fields.empty?
    end

    def length
      @fields.length
    end

    def each(&block)
      @fields.each(&block)
    end

    def collect(&block)
      @fields.collect(&block)
    end

    def field_names
      @fields.collect { |field| field.name_as_sym }
    end

    def has_field_name?(name)
      @fields.detect { |f| f.name_as_sym == name.to_sym }
    end

    def all_field_names_blank?
      @fields.all? { |f| f.name == nil }
    end

    def no_field_names_blank?
      @fields.all? { |f| f.name != nil }
    end

    def copy_fields(other)
      @fields.concat(other.fields)
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedChoices < SanitizedParameter
    def initialize(choices, endian)
      @choices = {}
      choices.each_pair do |key, val|
        if SanitizedParameter === val
          prototype = val
        else
          type, param = val
          prototype = SanitizedPrototype.new(type, param, endian)
        end

        if key == :default
          @choices.default = prototype
        else
          @choices[key] = prototype
        end
      end
    end

    def [](key)
      @choices[key]
    end
  end
  #----------------------------------------------------------------------------

  class SanitizedBigEndian < SanitizedParameter
    def endian
      :big
    end
  end

  class SanitizedLittleEndian < SanitizedParameter
    def endian
      :little
    end
  end
  #----------------------------------------------------------------------------

  # BinData objects are instantiated with parameters to determine their
  # behaviour.  These parameters must be sanitized to ensure their values
  # are valid.  When instantiating many objects with identical parameters,
  # such as an array of records, there is much duplicated sanitizing.
  #
  # The purpose of the sanitizing code is to eliminate the duplicated
  # validation.
  #
  # SanitizedParameters is a hash-like collection of parameters.  Its purpose
  # is to recursively sanitize the parameters of an entire BinData object chain
  # at a single time.
  class SanitizedParameters < Hash

    # Memoized constants
    BIG_ENDIAN    = SanitizedBigEndian.new
    LITTLE_ENDIAN = SanitizedLittleEndian.new

    class << self
      def sanitize(parameters, the_class)
        if SanitizedParameters === parameters
          parameters
        else
          SanitizedParameters.new(parameters, the_class, nil)
        end
      end
    end

    def initialize(parameters, the_class, endian)
      parameters.each_pair { |key, value| self[key.to_sym] = value }

      @the_class = the_class
      @endian    = endian

      sanitize!
    end

    alias_method :has_parameter?, :has_key?

    def needs_sanitizing?(key)
      parameter = self[key]

      parameter and not parameter.is_a?(SanitizedParameter)
    end

    def warn_replacement_parameter(bad_key, suggested_key)
      if has_parameter?(bad_key)
        warn ":#{bad_key} is not used with #{@the_class}.  " +
        "You probably want to change this to :#{suggested_key}"
      end
    end

    def warn_renamed_parameter(old_key, new_key)
      val = delete(old_key)
      if val
        self[new_key] = val
        warn ":#{old_key} has been renamed to :#{new_key} in #{@the_class}.  " +
        "Using :#{old_key} is now deprecated and will be removed in the future"
      end
    end

    def endian
      @endian || self[:endian]
    end
    attr_writer :endian

    def create_sanitized_endian(endian)
      if endian == :big
        BIG_ENDIAN
      elsif endian == :little
        LITTLE_ENDIAN
      else
        raise ArgumentError, "unknown value for endian '#{endian}'"
      end
    end

    def create_sanitized_params(params, the_class)
      SanitizedParameters.new(params, the_class, self.endian)
    end

    def create_sanitized_choices(choices)
      SanitizedChoices.new(choices, self.endian)
    end

    def create_sanitized_fields
      SanitizedFields.new(self.endian)
    end

    def create_sanitized_object_prototype(obj_type, obj_params)
      SanitizedPrototype.new(obj_type, obj_params, self.endian)
    end

    #---------------
    private

    def sanitize!
      ensure_no_nil_values
      merge_default_parameters!

      @the_class.sanitize_parameters!(self)

      ensure_mandatory_parameters_exist
      ensure_mutual_exclusion_of_parameters
    end

    def ensure_no_nil_values
      each do |key, value|
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

end
