require 'singleton'

module BinData
  # This registry contains a register of name -> class mappings.
  class Registry
    include Singleton

    def initialize
      @registry = {}
    end

    # Convert camelCase +name+ to underscore style.
    def underscore_name(name)
      name.to_s.sub(/.*::/, "").
                gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
                gsub(/([a-z\d])([A-Z])/,'\1_\2').
                tr("-", "_").
                downcase
    end

    # Registers the mapping of +name+ to +klass+.  +name+ is converted
    # from camelCase to underscore style.
    # Returns the converted name
    def register(name, klass)
      # convert camelCase name to underscore style
      name = underscore_name(name)

      # warn if replacing an existing class
      if $VERBOSE and (existing = @registry[name])
        warn "warning: replacing registered class #{existing} with #{klass}"
      end

      @registry[name] = klass
      name.dup
    end

    # Returns the class matching a previously registered +name+.
    def lookup(name)
      @registry[name.to_s]
    end
  end
end
