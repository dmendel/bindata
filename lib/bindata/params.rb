require 'bindata/lazy'

module BinData
  # BinData objects accept parameters when initializing.  AcceptedParameters
  # allow a BinData class to declaratively identify accepted parameters as
  # mandatory, optional, default or mutually exclusive.
  class AcceptedParameters
    class << self
      def define_all_accessors(obj_class)
        all_accessors = [:mandatory, :optional, :default, :mutually_exclusive]
        all_accessors.each do |accessor|
          define_accessor(obj_class, accessor)
        end
      end

      def get(obj_class)
        obj_class.__send__(internal_storage_method_name)
      end

      #-------------
      private

      def define_accessor(obj_class, accessor)
        singular_name = accessor_method_name(accessor)
        plural_name = singular_name + "s"

        ensure_parameter_storage_exists(obj_class, internal_storage_method_name)

        obj_class.class_eval <<-END
          def #{singular_name}(*args)
            #{internal_storage_method_name}.#{accessor}(*args)
          end
          alias_method :#{plural_name}, :#{singular_name}
        END
      end

      def accessor_method_name(accessor)
        "#{accessor}_parameter"
      end

      def internal_storage_method_name
        "_bindata_accepted_parameters_"
      end

      def ensure_parameter_storage_exists(obj_class, method_name)
        return if obj_class.instance_methods.include?(method_name)

        iv = "@#{method_name}"
        obj_class.class_eval <<-END
          def #{method_name}
            unless defined? #{iv}
              ancestor = ancestors[1..-1].find { |a| a.instance_variable_defined?(:#{iv}) }
              ancestor_params = ancestor.nil? ? nil : ancestor.instance_variable_get(:#{iv})
              #{iv} = AcceptedParameters.new(ancestor_params)
            end
            #{iv}
          end
        END
      end
    end

    def initialize(ancestor_params = nil)
      @mandatory = ancestor_params ? ancestor_params.mandatory : []
      @optional = ancestor_params ? ancestor_params.optional : []
      @default = ancestor_params ? ancestor_params.default : Hash.new
      @mutually_exclusive = ancestor_params ? ancestor_params.mutually_exclusive : []
    end

    def mandatory(*args)
      if not args.empty?
        ensure_valid_names(args)
        @mandatory.concat(args.collect { |a| a.to_sym })
        @mandatory.uniq!
      end
      @mandatory.dup
    end

    def optional(*args)
      if not args.empty?
        ensure_valid_names(args)
        @optional.concat(args.collect { |a| a.to_sym })
        @optional.uniq!
      end
      @optional.dup
    end

    def default(args = {})
      if not args.empty?
        ensure_valid_names(args.keys)
        args.each_pair do |k,v|
          @default[k.to_sym] = v
        end
      end
      @default.dup
    end

    def mutually_exclusive(*args)
      arg1, arg2 = args
      if arg1 != nil && arg2 != nil
        @mutually_exclusive.push([arg1.to_sym, arg2.to_sym])
        @mutually_exclusive.uniq!
      end
      @mutually_exclusive.dup
    end

    def all
      (@mandatory + @optional + @default.keys).uniq
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
          raise ArgumentError, "parameter ':#{prm}' must be specified"
        end
      end
    end

    def ensure_mutual_exclusion_of_parameters(params)
      return if params.length < 2

      @mutually_exclusive.each do |param1, param2|
        if params.has_key?(param1) and params.has_key?(param2)
          raise ArgumentError, "params ':#{param1}' and ':#{param2}' " +
                               "are mutually exclusive"
        end
      end
    end

    def ensure_valid_names(names)
      invalid_names = LazyEvaluator.instance_methods(true) +
                        Kernel.methods - ["type"]
      names.each do |name|
        name = name.to_s
        if invalid_names.include?(name)
          raise NameError.new("Rename parameter '#{name}' " +
                              "as it shadows an existing method.", name)
        end
      end
    end
  end
end
