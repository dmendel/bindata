require 'set'

module BinData
  # BinData objects accept parameters when initializing.  AcceptedParameters
  # allow a BinData class to declaratively identify accepted parameters as
  # mandatory, optional, default or mutually exclusive.
  class AcceptedParameters
    class << self
      def define_all_accessors(obj_class, param_name, accessor_prefix)
        all_accessors = [:mandatory, :optional, :default, :mutually_exclusive]
        all_accessors.each do |accessor|
          define_accessor(obj_class, param_name, accessor_prefix, accessor)
        end
      end

      def define_accessors(obj_class, param_name, *accessors)
        accessors.each do |accessor|
          define_accessor(obj_class, param_name, nil, accessor)
        end
      end

      def get(obj_class, param_name)
        obj_class.__send__(internal_storage_method_name(param_name))
      end

      #-------------
      private

      def define_accessor(obj_class, param_name, accessor_prefix, accessor)
        singular_name = accessor_method_name(accessor_prefix, accessor)
        plural_name = singular_name + "s"
        internal_storage_method = internal_storage_method_name(param_name)

        ensure_parameter_storage_exists(obj_class, internal_storage_method)

        obj_class.class_eval <<-END
          def #{singular_name}(*args)
            #{internal_storage_method}.#{accessor}(*args)
          end
          alias_method :#{plural_name}, :#{singular_name}
        END
      end

      def accessor_method_name(accessor_prefix, accessor)
        if accessor_prefix
          "#{accessor_prefix}_#{accessor}_parameter"
        else
          "#{accessor}_parameter"
        end
      end

      def internal_storage_method_name(param_name)
        "_bindata_accepted_parameters_#{param_name}"
      end

      def ensure_parameter_storage_exists(obj_class, method_name)
        return if obj_class.respond_to?(method_name)

        iv = "@#{method_name}"
        obj_class.class_eval <<-END
          def #{method_name}
            iv = "#{iv}".to_sym
            unless instance_variable_defined?(iv)
              ancestor = ancestors[1..-1].find { |a| a.instance_variable_defined?(iv) }
              ancestor_params = ancestor.nil? ? nil : ancestor.instance_variable_get(iv)
              instance_variable_set(iv, AcceptedParameters.new(ancestor_params))
            end
            instance_variable_get(iv)
          end
        END
      end
    end

    def initialize(ancestor_params = nil)
      @mandatory = ancestor_params ? ancestor_params.mandatory : Set.new
      @optional = ancestor_params ? ancestor_params.optional : Set.new
      @default = ancestor_params ? ancestor_params.default : Hash.new
      @mutually_exclusive = ancestor_params ? ancestor_params.mutually_exclusive : Set.new
    end

    def mandatory(*args)
      if not args.empty?
        @mandatory.merge(args.collect { |a| a.to_sym })
      end
      @mandatory.dup
    end

    def optional(*args)
      if not args.empty?
        @optional.merge(args.collect { |a| a.to_sym })
      end
      @optional.dup
    end

    def default(args = {})
      if not args.empty?
        args.each_pair do |k,v|
          @default[k.to_sym] = v
        end
      end
      @default.dup
    end

    def mutually_exclusive(*args)
      arg1, arg2 = args
      if arg1 != nil && arg2 != nil
        @mutually_exclusive.add([arg1.to_sym, arg2.to_sym])
      end
      @mutually_exclusive.dup
    end

    def all
      (@mandatory + @optional + @default.keys)
    end

    def sanitize_parameters!(sanitizer, params)
      merge_default_parameters!(params)
      ensure_mandatory_parameters_exist(params)
      ensure_mutual_exclusion_of_parameters(params)
    end

    #---------------
    private

    def merge_default_parameters!(params)
      @default.each do |k,v|
        params[k] = v unless params.has_key?(k)
      end
    end

    def ensure_mandatory_parameters_exist(params)
      @mandatory.each do |prm|
        unless params.has_key?(prm)
          raise ArgumentError, "parameter ':#{prm}' must be specified " +
                               "in #{self}"
        end
      end
    end

    def ensure_mutual_exclusion_of_parameters(params)
      @mutually_exclusive.each do |param1, param2|
        if params.has_key?(param1) and params.has_key?(param2)
          raise ArgumentError, "params #{param1} and #{param2} " +
                               "are mutually exclusive"
        end
      end
    end
  end
end
