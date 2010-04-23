module BinData
  module DSLMixin
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    module ClassMethods
      def dsl_parser(*args)
        @dsl_parser ||= DSLParser.new(self, *args)
        #:only_one_field, :multiple_fields, :mandatory_fieldnames, :optional_fieldnames, :no_fieldnames, :hidden_fields
      end

      def method_missing(symbol, *args, &block)
        dsl_parser.__send__(symbol, *args, &block)
      end
    end

    class DSLParser
      def initialize(the_class, *options)
        @the_class = the_class

        @options = parent_attribute(:options, []).dup

        options.each do |opt|
          case opt
          when :only_one_field
            @options.delete :multiple_fields
          when :multiple_fields
            @options.delete :only_one_field
          when :mandatory_fieldnames
            @options.delete :optional_fieldnames
            @options.delete :no_fieldnames
          when :optional_fieldnames
            @options.delete :mandatory_fieldnames
            @options.delete :no_fieldnames
          when :no_fieldnames
            @options.delete :mandatory_fieldnames
            @options.delete :optional_fieldnames
          end
          @options << opt
        end

        @endian = parent_attribute(:endian, nil)

        if @options.include?(:hidden_fields)
          @hide = parent_attribute(:hide, []).dup
        end

        if @options.include?(:multiple_fields)
          fields = parent_attribute(:fields, nil)
          if fields
            @fields = Sanitizer.new.clone_sanitized_fields(fields)
          else
            @fields = Sanitizer.new.create_sanitized_fields
          end
        end
      end

      def parent_attribute(attr, default = nil)
        parent = @the_class.superclass.respond_to?(:dsl_parser) ? @the_class.superclass.dsl_parser : nil
        if parent and parent.respond_to?(attr)
          parent.send(attr)
        else
          default
        end
      end

      attr_reader :options

      def endian(endian = nil)
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError,
                  "unknown value for endian '#{endian}' in #{@the_class}", caller(1)
        end
        @endian
      end

      def hide(*args)
        @hide.concat(args.collect { |name| name.to_s })
        @hide
      end

      def fields #:nodoc:
        @fields
      end

      def method_missing(symbol, *args) #:nodoc:
        name, params = args

        if name.is_a?(Hash)
          params = name
          name = nil
        end

        type = symbol
        name = name.to_s
        params ||= {}

        append_field(type, name, params)
      end

      #-------------
      private

      def append_field(type, name, params)
        ensure_valid_name(name)

        fields.add_field(type, name, params, endian)
      rescue UnknownTypeError => err
        raise TypeError, "unknown type '#{err.message}' for #{@the_class}", caller(2)
      end

      def ensure_valid_name(name)
        if fields.field_names.include?(name)
          raise SyntaxError, "duplicate field '#{name}' in #{@the_class}", caller(3)
        end
        if @the_class.instance_methods.collect { |meth| meth.to_s }.include?(name)
          raise NameError.new("", name),
                "field '#{name}' shadows an existing method in #{@the_class}", caller(3)
        end
        if BinData::Struct::RESERVED.include?(name)
          raise NameError.new("", name),
                "field '#{name}' is a reserved name in #{@the_class}", caller(3)
        end
      end
    end
  end
end
