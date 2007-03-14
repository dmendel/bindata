require 'singleton'

module BinData
  # This registry contains a register of name -> class mappings.
  class Registry
    include Singleton

    def initialize
      @registry = {}
    end

    # Registers the mapping of +name+ to +klass+.  +name+ is converted
    # from camelCase to underscore style.
    # Returns the converted name
    def register(name, klass)
      # convert camelCase name to underscore style
      underscore_name = name.to_s.sub(/.*::/, "").
                             gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
                             gsub(/([a-z\d])([A-Z])/,'\1_\2').
                             tr("-", "_").
                             downcase

      # warn if replacing an existing class
      if $VERBOSE and (existing = @registry[underscore_name])
        warn "warning: replacing registered class #{existing} with #{klass}"
      end

      @registry[underscore_name] = klass
      underscore_name.dup
    end

    # Returns the class matching a previously registered +name+.
    def lookup(name)
      @registry[name.to_s]
    end
  end
end
