require 'bindata/registry'
require 'forwardable'

module BinData

  # A BinData object accepts arbitrary parameters.  This class only contains
  # parameters that have been sanitized, and categorizes them according to
  # whether they are BinData::Base.accepted_internal_parameters or are custom.
  class SanitizedParameters
    extend Forwardable

    # Sanitize the given parameters.
    def initialize(the_class, params)
      @hash = params
      @internal_parameters = {}
      @custom_parameters = {}

      # partition parameters into known and custom parameters
      @hash.each do |k,v|
        k = k.to_sym
        if v.nil?
          raise ArgumentError, "parameter :#{k} has nil value in #{the_class}"
        end

        if the_class.accepted_internal_parameters.include?(k)
          @internal_parameters[k] = v
        else
          @custom_parameters[k] = v
        end
      end
    end

    attr_reader :internal_parameters, :custom_parameters

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
      def sanitize(the_class, params)
        if SanitizedParameters === params
          params
        else
          sanitizer = self.new
          sanitizer.sanitized_params(the_class, params)
        end
      end
    end

    def initialize
      @endian = nil
      @seen   = []
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

    def sanitized_params(the_class, params)
      new_params = params.nil? ? {} : params.dup

      result = nil
      if can_sanitize_parameters?(the_class)
        with_class_to_sanitize(the_class) do
          the_class.sanitize_parameters!(self, new_params)
          result = SanitizedParameters.new(the_class, new_params)
        end
      else
        store_current_endian!(the_class, new_params)
        result = new_params
      end

      result
    end

    #---------------
    private

    def can_sanitize_parameters?(the_class)
      not need_to_delay_sanitizing?(the_class)
    end

    def need_to_delay_sanitizing?(the_class)
      the_class.recursive? and @seen.include?(the_class)
    end

    def with_class_to_sanitize(the_class, &block)
      @seen.push(the_class)
      yield
      @seen.pop
    end

    def store_current_endian!(the_class, params)
      if can_store_endian?(the_class, params)
        params[:endian] = @endian 
      end
    end

    def can_store_endian?(the_class, params)
      (@endian != nil and 
       the_class.accepted_internal_parameters.include?(:endian) and
       not params.has_key?(:endian))
    end
  end
end

