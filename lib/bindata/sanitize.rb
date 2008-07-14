require 'forwardable'

module BinData
  class Sanitizer
    def initialize
      @seen = []
    end

    def sanitize(klass, params, endian = nil)
#      params ||= {}
#      params = klass.sanitize_parameters(self, params, endian)
#      return SanitizedParameters.new(klass, params, endian)

      params ||= {}
      if @seen.include?(klass)
        if endian != nil and klass.accepted_parameters.include?(:endian) and ! params.has_key?(:endian)
          params = params.dup
          params[:endian] = endian
        end
        params
      else
        if BinData.const_defined?(:MultiValue) and klass.ancestors.include? BinData.const_get(:MultiValue)
          @seen.push klass
        end
        new_params = klass.sanitize_parameters(self, params, endian)
        p = SanitizedParameters.new(klass, new_params, endian)
        p
      end
    end

    def lookup(name, endian)
    end
  end

  # A BinData object accepts arbitrary parameters.  This class ensures that
  # the parameters have been sanitized, and categorizes them according to
  # whether they are BinData::Base.accepted_parameters or are extra.
  class SanitizedParameters
    extend Forwardable

    # Sanitize the given parameters.
    def initialize(klass, params, *args)
#      params ||= {}
#      @hash = klass.sanitize_parameters(params, *args)
      @hash = params
      @accepted_parameters = {}
      @extra_parameters = {}

      # partition parameters into known and extra parameters
      @hash.each do |k,v|
        k = k.to_sym
        if v.nil?
          raise ArgumentError, "parameter :#{k} has nil value in #{klass}"
        end

        if klass.accepted_parameters.include?(k)
          @accepted_parameters[k] = v
        else
          @extra_parameters[k] = v
        end
      end
    end

    attr_reader :accepted_parameters, :extra_parameters

    def_delegators :@hash, :[], :has_key?, :include?, :keys
  end
end
