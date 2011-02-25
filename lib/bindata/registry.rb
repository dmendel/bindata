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

      formatted_name = lookup_key(name)
      warn_if_name_is_already_registered(formatted_name, class_to_register)

      @registry[formatted_name] = class_to_register
    end

    def unregister(name)
      formatted_name = lookup_key(name)
      @registry.delete(formatted_name)
    end

    def lookup(name, endian = nil)
      key = lookup_key(name, endian)
      try_registering_key(key) unless @registry.has_key?(key)

      @registry[key] || raise(UnRegisteredTypeError, name.to_s)
    end

    def normalize_name(name, endian = nil)
      if lookup(name, endian)
        lookup_key(name, endian)
      end
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

    def lookup_key(name, endian = nil)
      name = underscore_name(name)

      result = name
      if endian != nil
        if /^u?int\d+$/ =~ name
          result = name + ((endian == :little) ? "le" : "be")
        elsif /^(float|double)$/ =~ name
          result = name + ((endian == :little) ? "_le" : "_be")
        end
      end
      result
    end

    def try_registering_key(key)
      if /^u?int\d+(le|be)$/ =~ key or /^bit\d+(le)?$/ =~ key
        class_name = key.gsub(/(?:^|_)(.)/) { $1.upcase }
        begin
          register(key, BinData::const_get(class_name))
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
