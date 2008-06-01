require 'forwardable'

module BinData
  # A BinData object accepts arbitrary parameters.  This class ensures that
  # the parameters have been sanitized, and categorizes them according to
  # whether they are BinData::Base.accepted_parameters or are extra.
  class SanitizedParameters
    extend Forwardable

    # Sanitize the given parameters.
    def initialize(klass, params, *args)
      params ||= {}
      @hash = klass.sanitize_parameters(params, *args)
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
