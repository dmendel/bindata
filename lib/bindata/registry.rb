module BinData
  # This registry contains a register of name -> class mappings.
  #
  # Names are stored in under_score_style, not camelCase.
  class Registry

    def initialize
      @registry = {}
    end

    def register(name, class_to_register)
      formatted_name = underscore_name(name)
      warn_if_name_is_already_registered(formatted_name, class_to_register)

      @registry[formatted_name] = class_to_register
    end

    def lookup(name, endian = nil)
      key = underscore_name(name.to_s)

      result = @registry[key]
      if result.nil?
        result = @registry[merge_key_and_endian(key, endian)]
      end
      result
    end

    def is_registered?(name, endian = nil)
      lookup(name, endian) != nil
    end

    # Convert camelCase +name+ to underscore style.
    def underscore_name(name)
      name.to_s.sub(/.*::/, "").
                gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
                gsub(/([a-z\d])([A-Z])/,'\1_\2').
                tr("-", "_").
                downcase
    end

    #---------------
    private

    def merge_key_and_endian(key, endian)
      result = key
      if endian != nil
        if /^u?int\d+$/ =~ key
          result = key + ((endian == :little) ? "le" : "be")
        elsif /^(float|double)$/ =~ key
          result = key + ((endian == :little) ? "_le" : "_be")
        end
      end
      result
    end

    def warn_if_name_is_already_registered(name, class_to_register)
      if $VERBOSE and @registry.has_key?(name)
        prev_class = @registry[name]
        warn "warning: replacing registered class #{prev_class} " +
             "with #{class_to_register}"
      end
    end
  end

  # A singleton registry of all registered classes.
  RegisteredClasses = Registry.new
end
