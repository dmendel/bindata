require 'forwardable'

module BinData

  # A BinData object accepts arbitrary parameters.  This class only contains
  # parameters that have been sanitized, and categorizes them according to
  # whether they are BinData::Base.internal_parameters or are extra.
  class SanitizedParameters
    extend Forwardable

    # Sanitize the given parameters.
    def initialize(klass, params)
      @hash = params
      @internal_parameters = {}
      @extra_parameters = {}

      # partition parameters into known and extra parameters
      @hash.each do |k,v|
        k = k.to_sym
        if v.nil?
          raise ArgumentError, "parameter :#{k} has nil value in #{klass}"
        end

        if klass.internal_parameters.include?(k)
          @internal_parameters[k] = v
        else
          @extra_parameters[k] = v
        end
      end
    end

    attr_reader :internal_parameters, :extra_parameters

    def_delegators :@hash, :[], :has_key?, :include?, :keys
  end

  # The Sanitizer sanitizes the parameters that are passed when creating a
  # BinData object.  Sanitizing consists of checking for mandatory, optional
  # and default parameters and ensuring the values of known parameters are
  # valid.
  class Sanitizer

    class << self

      # Sanitize +params+ for +obj+.
      # Returns sanitized parameters.
      def sanitize(klass, params)
        if SanitizedParameters === params
          params
        else
          sanitizer = self.new
          sanitizer.sanitize_params(klass, params)
        end
      end

      # Returns true if +type+ is registered.
      def type_exists?(type, endian = nil)
        lookup(type, endian) != nil
      end

      # Returns the class matching a previously registered +name+.
      def lookup(name, endian)
        name = name.to_s
        klass = Registry.instance.lookup(name)
        if klass.nil? and endian != nil
          # lookup failed so attempt endian lookup
          if /^u?int\d{1,3}$/ =~ name
            new_name = name + ((endian == :little) ? "le" : "be")
            klass = Registry.instance.lookup(new_name)
          elsif ["float", "double"].include?(name)
            new_name = name + ((endian == :little) ? "_le" : "_be")
            klass = Registry.instance.lookup(new_name)
          end
        end
        klass
      end
    end

    # Create a new Sanitizer.
    def initialize
      @seen   = []
      @endian = nil
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

    # Converts +type+ into the appropriate class.
    def lookup_klass(type)
      klass = self.class.lookup(type, @endian)
      raise TypeError, "unknown type '#{type}'" if klass.nil?
      klass
    end

    # Sanitizes +params+ for +klass+.
    # Returns +sanitized_params+.
    def sanitize_params(klass, params)
      new_params = params.nil? ? {} : params.dup

      if klass.recursive? and @seen.include?(klass)
        # This klass is defined recursively.  Remember the current endian
        # and delay sanitizing the parameters until later.
        new_params[:endian] = @endian if can_store_endian?(klass, new_params)
        ret_val = new_params
      else
        @seen.push(klass)

        # Sanitize new_params.  This may recursively call this method again.
        klass.sanitize_parameters!(self, new_params)
        ret_val = SanitizedParameters.new(klass, new_params)

        @seen.pop
      end

      ret_val
    end

    #---------------
    private

    # Can we store the current endian for later?
    def can_store_endian?(klass, params)
      (@endian != nil and klass.internal_parameters.include?(:endian) and
       not params.has_key?(:endian))
    end
  end
end

