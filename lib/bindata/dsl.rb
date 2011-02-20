module BinData
  module DSLMixin
    def self.included(base) #:nodoc:
      base.extend ClassMethods
    end

    module ClassMethods
      # Defines the DSL Parser for this BinData object.  Allowed +args+ are:
      #
      # [<tt>:only_one_field</tt>]         Only one field may be declared.
      # [<tt>:multiple_fields</tt>]        Multiple fields may be declared.
      # [<tt>:hidden_fields</tt>]          Hidden fields are allowed.
      # [<tt>:sanitize_fields</tt>]        Fields are to be sanitized.
      # [<tt>:mandatory_fieldnames</tt>]   Fieldnames are mandatory.
      # [<tt>:optional_fieldnames</tt>]    Fieldnames are optional.
      # [<tt>:fieldnames_for_choices</tt>] Fieldnames are choice keys.
      # [<tt>:no_fieldnames</tt>]          Fieldnames are prohibited.
      # [<tt>:all_or_none_fieldnames</tt>] All fields must have names, or
      #                                    none may have names.
      def dsl_parser(*args)
        @dsl_parser ||= DSLParser.new(self, *args)
      end

      def method_missing(symbol, *args, &block) #:nodoc:
        dsl_parser.__send__(symbol, *args, &block)
      end

      # Assert object is not an array or string.
      def to_ary; nil; end
      def to_str; nil; end
    end

    # An array containing a field definition of the form
    # expected by BinData::Struct.
    class UnSanitizedField < ::Array
      def initialize(type, name, params)
        super()
        self << type << name << params
      end
      def type
        self[0]
      end
      def name
        self[1]
      end
      def params
        self[2]
      end
      def to_type_params
        [self.type, self.params]
      end
    end

    class UnSanitizedFields < ::Array
      def field_names
        collect { |f| f.name }
      end

      def add_field(type, name, params, endian)
        normalized_endian = endian.respond_to?(:endian) ? endian.endian : endian
        normalized_type = RegisteredClasses.normalize_name(type, normalized_endian)
        self << UnSanitizedField.new(normalized_type, name, params)
      end
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
      def initialize(the_class, *options)
        options = options_for_parser_type(options[0]) if options.length == 1

        @the_class = the_class
        @options   = parent_options_plus_these(options)
        @endian    = parent_attribute(:endian, nil)

        if option?(:hidden_fields)
          @hide = parent_attribute(:hide, []).dup
        end

        if option?(:sanitize_fields)
          fields = parent_attribute(:fields, nil)
          @fields = Sanitizer.new.create_sanitized_fields(fields)
        else
          fields = parent_attribute(:fields, UnSanitizedFields.new)
          @fields = fields.dup
        end
      end

      attr_reader :options

      def options_for_parser_type(parser_type)
        case parser_type
        when :struct
          [:multiple_fields, :optional_fieldnames, :sanitize_fields, :hidden_fields]
        when :array
          [:multiple_fields, :optional_fieldnames]
        when :choice
          [:multiple_fields, :all_or_none_fieldnames, :fieldnames_for_choices]
        when :primitive
          [:multiple_fields, :optional_fieldnames, :sanitize_fields]
        when :wrapper
          [:only_one_field, :no_fieldnames]
        else
          raise "unknown parser type #{parser_type}"
        end
      end

      def endian(endian = nil)
        if endian.nil?
          @endian
        elsif endian.respond_to? :endian
          @endian = endian
        elsif [:little, :big].include?(endian)
          @endian = Sanitizer.new.create_sanitized_endian(endian)
        else
          dsl_raise ArgumentError, "unknown value for endian '#{endian}'"
        end
      end

      def hide(*args)
        if option?(:hidden_fields)
          hidden = args.collect do |name|
                     unless Symbol === name
                       warn "Hidden field '#{name}' should be provided as a symbol.  Using strings is deprecated"
                     end
                     name.to_sym
                   end
          @hide.concat(hidden.compact)
          @hide
        end
      end

      def fields
        @fields
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

      def to_array_params
        case fields.length
        when 0
          {}
        when 1
          {:type => fields[0].to_type_params}
        else
          {:type => [:struct, to_struct_params]}
        end
      end

      def to_choice_params
        all_blank = fields.field_names.all? { |el| el == "" }
        if fields.length == 0
          {}
        elsif all_blank
          {:choices => fields.collect { |f| f.to_type_params }}
        else
          choices = {}
          fields.each { |f| choices[f.name] = f.to_type_params }
          {:choices => choices}
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

      def dsl_raise(exception, message)
        backtrace = caller
        backtrace.shift while %r{bindata/dsl.rb} =~ backtrace.first

        raise exception, message + " in #{@the_class}", backtrace
      end

      def option?(opt)
        @options.include?(opt)
      end

      def parent_attribute(attr, default = nil)
        parent = @the_class.superclass.respond_to?(:dsl_parser) ? @the_class.superclass.dsl_parser : nil
        if parent and parent.respond_to?(attr)
          parent.send(attr)
        else
          default
        end
      end

      def parent_options_plus_these(options)
        result = parent_attribute(:options, []).dup

        mutexes = [
          [:only_one_field, :multiple_fields],
          [:mandatory_fieldnames, :optional_fieldnames, :no_fieldnames, :all_or_none_fieldnames]
        ]

        options.each do |opt|
          mutexes.each do |mutex|
            if mutex.include?(opt)
              result -= mutex
            end
          end

          result << opt
        end

        result
      end

      def name_from_field_declaration(args)
        name, params = args
        if name.nil? or name.is_a?(Hash)
          ""
        elsif name.is_a?(Symbol)
          name.to_s
        else
          name
        end
      end

      def params_from_field_declaration(type, args, &block)
        params = params_from_args(args)

        if block_given? and BlockParsers.has_key?(type)
          params.merge(BlockParsers[type].extract_params(endian, &block))
        else
          params
        end
      end

      def params_from_args(args)
        name, params = args
        params = name if name.is_a?(Hash)

        params || {}
      end

      def append_field(type, name, params)
        if too_many_fields?
          dsl_raise SyntaxError, "attempting to wrap more than one type"
        end

        ensure_valid_name(name)

        fields.add_field(type, name, params, endian)
      rescue UnRegisteredTypeError => err
        dsl_raise TypeError, "unknown type '#{err.message}'"
      end

      def ensure_valid_name(name)
        if must_not_have_a_name_failed?(name)
          dsl_raise SyntaxError, "field must not have a name"
        end

        if all_or_none_names_failed?(name)
          dsl_raise SyntaxError, "fields must either all have names, or none must have names"
        end

        if must_have_a_name_failed?(name)
          dsl_raise SyntaxError, "field must have a name"
        end

        unless option?(:fieldnames_for_choices)
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
        option?(:no_fieldnames) and name != ""
      end

      def must_have_a_name_failed?(name)
        option?(:mandatory_fieldnames) and name == ""
      end

      def all_or_none_names_failed?(name)
        if option?(:all_or_none_fieldnames) and not fields.empty?
          all_names_blank = fields.field_names.all? { |n| n == "" }
          no_names_blank = fields.field_names.all? { |n| n != "" }

          (name != "" and all_names_blank) or (name == "" and no_names_blank)
        else
          false
        end
      end

      def malformed_name?(name)
        name != "" and /^[a-z_]\w*$/ !~ name
      end

      def duplicate_name?(name)
        name != "" and fields.field_names.include?(name)
      end

      def name_shadows_method?(name)
        name != "" and @the_class.method_defined?(name)
      end

      def name_is_reserved?(name)
        name != "" and BinData::Struct::RESERVED.include?(name)
      end
    end

    class StructBlockParser
      def self.extract_params(endian, &block)
        parser = DSLParser.new(BinData::Struct, :struct)
        parser.endian endian
        parser.instance_eval(&block)

        parser.to_struct_params
      end
    end

    class ArrayBlockParser
      def self.extract_params(endian, &block)
        parser = DSLParser.new(BinData::Array, :array)
        parser.endian endian
        parser.instance_eval(&block)

        parser.to_array_params
      end
    end

    class ChoiceBlockParser
      def self.extract_params(endian, &block)
        parser = DSLParser.new(BinData::Choice, :choice)
        parser.endian endian
        parser.instance_eval(&block)

        parser.to_choice_params
      end
    end

    BlockParsers = {
      :struct => StructBlockParser,
      :array  => ArrayBlockParser,
      :choice => ChoiceBlockParser,
    }
  end
end
