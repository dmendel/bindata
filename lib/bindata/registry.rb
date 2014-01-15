module BinData

  class UnRegisteredTypeError < StandardError ; end

  # This registry contains a register of name -> class mappings.
  #
  # Numerics (integers and floating point numbers) have an endian property as
  # part of their name (e.g. int32be, float_le).  The lookup can either be
  # on the full name, or on the shortened name plus endian (e.g. "int32", :big)
  #
  # Names are stored in under_score_style, not camelCase.
  class Registry

    def initialize
      @registry = {}
    end

    def register(name, class_to_register)
      return if class_to_register.nil?

      formatted_name = underscore_name(name)
      warn_if_name_is_already_registered(formatted_name, class_to_register)

      @registry[formatted_name] = class_to_register
    end

    def unregister(name)
      @registry.delete(underscore_name(name))
    end

    def lookup(name, endian = nil)
      key = normalize_name(name, endian)
      @registry[key] || raise(UnRegisteredTypeError, name.to_s)
    end

    def normalize_name(name, endian = nil)
      name = underscore_name(name)
      return name if is_registered?(name)

      name = name_with_endian(name, endian)
      return name if is_registered?(name)

      name
    end

    # Convert CamelCase +name+ to underscore style.
    def underscore_name(name)
      name.to_s.sub(/.*::/, "").
                gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
                gsub(/([a-z\d])([A-Z])/,'\1_\2').
                tr("-", "_").
                downcase
    end

    #---------------
    private

    def name_with_endian(name, endian)
      return name if endian.nil?

      suffix = (endian == :little) ? "le" : "be"
      if /^u?int\d+$/ =~ name
        name + suffix
      else
        name + "_" + suffix
      end
    end

    def is_registered?(name)
      register_dynamic_class(name) unless @registry.has_key?(name)

      @registry.has_key?(name)
    end

    def register_dynamic_class(name)
      if /^u?int\d+(le|be)$/ =~ name or /^s?bit\d+(le)?$/ =~ name
        class_name = name.gsub(/(?:^|_)(.)/) { $1.upcase }
        begin
          BinData::const_get(class_name)
        rescue NameError
        end
      end
    end

    def warn_if_name_is_already_registered(name, class_to_register)
      prev_class = @registry[name]
      if $VERBOSE and prev_class and prev_class != class_to_register
        warn "warning: replacing registered class #{prev_class} " +
             "with #{class_to_register}"
      end
    end
  end

  # A singleton registry of all registered classes.
  RegisteredClasses = Registry.new
end
