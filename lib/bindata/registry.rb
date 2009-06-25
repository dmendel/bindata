module BinData
  # This registry contains a register of name -> class mappings.
  #
  # Names are stored in under_score_style, not camelCase.
  class Registry

    def initialize
      @registry = {}
    end

    def register(name, class_to_register)
      formatted_name = lookup_key(name)
      warn_if_name_is_already_registered(formatted_name, class_to_register)

      @registry[formatted_name] = class_to_register
    end

    def lookup(name, endian = nil)
      key = lookup_key(name, endian)

      @registry[key] || lookup_int(key)
    end

    def is_registered?(name, endian = nil)
      @registry.has_key?(lookup_key(name, endian))
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

    def lookup_int(key)
      if /^(u?)int(\d+)(le|be)$/ =~ key
        signed = $1 == "u" ? :unsigned : :signed
        nbits  = $2.to_i
        endian = $3 == "le" ? :little : :big
        if nbits > 0 and (nbits % 8) == 0
          if BinData.const_defined?(:Integer)
            BinData::Integer.define_class(nbits, endian, signed)
          end
        end
      elsif /^bit(\d+)(le)?$/ =~ key
        nbits  = $1.to_i
        endian = $2 == "le" ? :little : :big
        if BinData.const_defined?(:BitField)
          BinData::BitField.define_class(nbits, endian)
        end
      end

      @registry[key]
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
