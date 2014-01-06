module BinData
  # Extracts args for Records and Buffers.
  #
  # Foo.new(:bar => "baz) is ambiguous as to whether :bar is a value or parameter.
  #
  # BaseArgExtractor always assumes :bar is parameter.  This extractor correctly
  # identifies it as value or parameter.
  class MultiFieldArgExtractor
    class << self
      def extract(the_class, the_args)
        value, parameters, parent = BaseArgExtractor.extract(the_class, the_args)

        if parameters_is_value?(the_class, value, parameters)
          value = parameters
          parameters = {}
        end

        [value, parameters, parent]
      end

      def parameters_is_value?(the_class, value, parameters)
        if value.nil? and parameters.length > 0
          field_names_in_parameters?(the_class, parameters)
        else
          false
        end
      end

      def field_names_in_parameters?(the_class, parameters)
        field_names = the_class.fields.field_names
        param_keys = parameters.keys

        (field_names & param_keys).length > 0
      end
    end
  end

  module DSLMixin
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    module ClassMethods

      def dsl_parser(parser_type = nil)
        unless defined? @dsl_parser
          parser_type = superclass.dsl_parser.parser_type if parser_type.nil?
          @dsl_parser = DSLParser.new(self, parser_type)
        end
        @dsl_parser
      end

      def method_missing(symbol, *args, &block) #:nodoc:
        dsl_parser.__send__(symbol, *args, &block)
      end

      # Assert object is not an array or string.
      def to_ary; nil; end
      def to_str; nil; end
    end

    # A DSLParser parses and accumulates field definitions of the form
    #
    #   type name, params
    #
    # where:
    #   * +type+ is the under_scored name of a registered type
    #   * +name+ is the (possible optional) name of the field
    #   * +params+ is a hash containing any parameters
    #
    class DSLParser
      def initialize(the_class, parser_type)
        @the_class   = the_class
        @parser_type = parser_type
        @endian      = parent_attribute(:endian, nil)
      end

      attr_reader :parser_type

      def endian(endian = nil)
        if endian.nil?
          @endian
        elsif endian == :big or endian == :little
          @endian = endian
        else
          dsl_raise ArgumentError, "unknown value for endian '#{endian}'"
        end
      end

      def hide(*args)
        if option?(:hidden_fields)
          hidden = args.collect { |name| name.to_sym }

          unless defined? @hide
            @hide = parent_attribute(:hide, []).dup
          end

          @hide.concat(hidden.compact)
          @hide
        end
      end

      def fields
        unless defined? @fields
          fields = parent_attribute(:fields, nil)
          @fields = SanitizedFields.new(endian)
          @fields.copy_fields(fields) if fields
        end

        @fields
      end

      def dsl_params
        case @parser_type
        when :struct
          to_struct_params
        when :array
          to_array_params
        when :buffer
          to_array_params
        when :choice
          to_choice_params
        when :primitive
          to_struct_params
        else
          raise "unknown parser type #{@parser_type}"
        end
      end

      def method_missing(symbol, *args, &block) #:nodoc:
        type   = symbol
        name   = name_from_field_declaration(args)
        params = params_from_field_declaration(type, args, &block)

        append_field(type, name, params)
      end

      #-------------
      private

      def option?(opt)
        options.include?(opt)
      end

      def options
        case @parser_type
        when :struct
          [:multiple_fields, :optional_fieldnames, :hidden_fields]
        when :array
          [:multiple_fields, :optional_fieldnames]
        when :buffer
          [:multiple_fields, :optional_fieldnames]
        when :choice
          [:multiple_fields, :all_or_none_fieldnames, :fieldnames_are_values]
        when :primitive
          [:multiple_fields, :optional_fieldnames]
        else
          raise "unknown parser type #{parser_type}"
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

      def name_from_field_declaration(args)
        name, params = args
        if name == "" or name.is_a?(Hash)
          nil
        else
          name
        end
      end

      def params_from_field_declaration(type, args, &block)
        params = params_from_args(args)

        if block_given?
          params.merge(params_from_block(type, &block))
        else
          params
        end
      end

      def params_from_args(args)
        name, params = args
        params = name if name.is_a?(Hash)

        params || {}
      end

      def params_from_block(type, &block)
        bindata_classes = {
          :array  => BinData::Array,
          :buffer => BinData::Buffer,
          :choice => BinData::Choice,
          :struct => BinData::Struct
        }

        if bindata_classes.include?(type)
          parser = DSLParser.new(bindata_classes[type], type)
          parser.endian(endian)
          parser.instance_eval(&block)

          parser.dsl_params
        else
          {}
        end
      end

      def append_field(type, name, params)
        ensure_valid_field(name)

        fields.add_field(type, name, params)
      rescue ArgumentError => err
        dsl_raise ArgumentError, err.message
      rescue UnRegisteredTypeError => err
        dsl_raise TypeError, "unknown type '#{err.message}'"
      end

      def ensure_valid_field(field_name)
        if too_many_fields?
          dsl_raise SyntaxError, "attempting to wrap more than one type"
        end

        if must_not_have_a_name_failed?(field_name)
          dsl_raise SyntaxError, "field must not have a name"
        end

        if all_or_none_names_failed?(field_name)
          dsl_raise SyntaxError, "fields must either all have names, or none must have names"
        end

        if must_have_a_name_failed?(field_name)
          dsl_raise SyntaxError, "field must have a name"
        end

        ensure_valid_name(field_name)
      end

      def ensure_valid_name(name)
        if name and not option?(:fieldnames_are_values)
          if malformed_name?(name)
            dsl_raise NameError.new("", name), "field '#{name}' is an illegal fieldname"
          end

          if duplicate_name?(name)
            dsl_raise SyntaxError, "duplicate field '#{name}'"
          end

          if name_shadows_method?(name)
            dsl_raise NameError.new("", name), "field '#{name}' shadows an existing method"
          end

          if name_is_reserved?(name)
            dsl_raise NameError.new("", name), "field '#{name}' is a reserved name"
          end
        end
      end

      def too_many_fields?
        option?(:only_one_field) and not fields.empty?
      end

      def must_not_have_a_name_failed?(name)
        option?(:no_fieldnames) and name != nil
      end

      def must_have_a_name_failed?(name)
        option?(:mandatory_fieldnames) and name.nil?
      end

      def all_or_none_names_failed?(name)
        if option?(:all_or_none_fieldnames) and not fields.empty?
          all_names_blank = fields.all_field_names_blank?
          no_names_blank = fields.no_field_names_blank?

          (name != nil and all_names_blank) or (name == nil and no_names_blank)
        else
          false
        end
      end

      def malformed_name?(name)
        /^[a-z_]\w*$/ !~ name.to_s
      end

      def duplicate_name?(name)
        fields.has_field_name?(name)
      end

      def name_shadows_method?(name)
        @the_class.method_defined?(name)
      end

      def name_is_reserved?(name)
        BinData::Struct::RESERVED.include?(name.to_sym)
      end

      def dsl_raise(exception, message)
        backtrace = caller
        backtrace.shift while %r{bindata/dsl.rb} =~ backtrace.first

        raise exception, message + " in #{@the_class}", backtrace
      end

      def to_array_params
        case fields.length
        when 0
          {}
        when 1
          {:type => fields[0].prototype}
        else
          {:type => [:struct, to_struct_params]}
        end
      end

      def to_choice_params
        if fields.length == 0
          {}
        elsif fields.all_field_names_blank?
          {:choices => fields.collect { |f| f.prototype }}
        else
          choices = {}
          fields.each { |f| choices[f.name] = f.prototype }
          {:choices => choices}
        end
      end

      def to_struct_params
        result = {:fields => fields}
        if not endian.nil?
          result[:endian] = endian
        end
        if option?(:hidden_fields) and not hide.empty?
          result[:hide] = hide
        end

        result
      end
    end
  end
end
