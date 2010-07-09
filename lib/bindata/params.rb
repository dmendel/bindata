require 'bindata/lazy'

module BinData
  module AcceptedParametersMixin
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    # Class methods to mix in to BinData::Base
    module ClassMethods
      # Mandatory parameters must be present when instantiating a data object.
      def mandatory_parameters(*args)
        accepted_parameters.mandatory(*args)
      end

      # Optional parameters may be present when instantiating a data object.
      def optional_parameters(*args)
        accepted_parameters.optional(*args)
      end

      # Default parameters can be overridden when instantiating a data object.
      def default_parameters(*args)
        accepted_parameters.default(*args)
      end

      # Mutually exclusive parameters may not all be present when
      # instantiating a data object.
      def mutually_exclusive_parameters(*args)
        accepted_parameters.mutually_exclusive(*args)
      end

      alias_method :mandatory_parameter, :mandatory_parameters
      alias_method :optional_parameter, :optional_parameters
      alias_method :default_parameter, :default_parameters

      def accepted_parameters #:nodoc:
        unless defined? @accepted_parameters
          ancestor_params = superclass.respond_to?(:accepted_parameters) ? superclass.accepted_parameters : nil
          @accepted_parameters = AcceptedParameters.new(ancestor_params)
        end
        @accepted_parameters
      end
    end

    # BinData objects accept parameters when initializing.  AcceptedParameters
    # allow a BinData class to declaratively identify accepted parameters as
    # mandatory, optional, default or mutually exclusive.
    class AcceptedParameters

      def self.invalid_parameter_names
        unless defined? @invalid_names
          all_names = LazyEvaluator.instance_methods(true) + Kernel.methods
          all_names.collect! { |name| name.to_s }
          allowed_names = ["type"]
          invalid_names = (all_names - allowed_names).uniq
	  @invalid_names = Hash[*invalid_names.collect { |key| [key, true] }.flatten]
        end
        @invalid_names
      end

      def initialize(ancestor_parameters = nil)
        if ancestor_parameters
          @mandatory = ancestor_parameters.mandatory
          @optional  = ancestor_parameters.optional
          @default   = ancestor_parameters.default
          @mutually_exclusive = ancestor_parameters.mutually_exclusive
        else
          @mandatory = []
          @optional  = []
          @default   = Hash.new
          @mutually_exclusive = []
        end
      end

      def mandatory(*args)
        if not args.empty?
          ensure_valid_names(args)
          @mandatory.concat(args.collect { |arg| arg.to_sym })
          @mandatory.uniq!
        end
        @mandatory.dup
      end

      def optional(*args)
        if not args.empty?
          ensure_valid_names(args)
          @optional.concat(args.collect { |arg| arg.to_sym })
          @optional.uniq!
        end
        @optional.dup
      end

      def default(args = {})
        if not args.empty?
          ensure_valid_names(args.keys)
          args.each_pair do |param, value|
            @default[param.to_sym] = value
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

      #---------------
      private

      def ensure_valid_names(names)
        invalid_names = self.class.invalid_parameter_names
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
end

