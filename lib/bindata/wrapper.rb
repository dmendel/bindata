require 'bindata/base'
require 'bindata/dsl'

module BinData
  # A Wrapper allows the creation of new BinData types that
  # provide default parameters.
  #
  #   require 'bindata'
  #
  #   class Uint8Array < BinData::Wrapper
  #     default_parameter :initial_element_value => 0
  #
  #     array :initial_length => 2 do
  #       uint8 :initial_value => :initial_element_value
  #     end
  #   end
  #
  #   arr = Uint8Array.new
  #   arr.snapshot #=> [0, 0]
  #
  #   arr = Uint8Array.new(:initial_length => 5, :initial_element_value => 3)
  #   arr.snapshot #=> [3, 3, 3, 3 ,3]
  #   
  class Wrapper < BinData::Base
    include DSLMixin

    register_subclasses
    dsl_parser :only_one_field, :no_fieldnames

    class << self
      def sanitize_parameters!(params, sanitizer) #:nodoc:
        raise "no wrapped type was specified in #{self}" if field.nil?

        wrapped_type = field.type
        wrapped_params = field.params.dup

        params.move_unknown_parameters_to(wrapped_params)

        params[:wrapped] = sanitizer.create_sanitized_object_prototype(wrapped_type, wrapped_params, endian)
      end
    end

    mandatory_parameter :wrapped

    def initialize_instance
      prototype = get_parameter(:wrapped)
      @wrapped = prototype.instantiate(nil, self)
    end

    def clear #:nodoc:
      @wrapped.clear
    end

    def clear? #:nodoc:
      @wrapped.clear?
    end

    def assign(val)
      @wrapped.assign(val)
    end

    def snapshot
      @wrapped.snapshot
    end

    def respond_to?(symbol, include_private = false) #:nodoc:
      @wrapped.respond_to?(symbol, include_private) || super
    end

    def method_missing(symbol, *args, &block) #:nodoc:
      @wrapped.__send__(symbol, *args, &block)
    end

    def do_read(io) #:nodoc:
      @wrapped.do_read(io)
    end

    def do_write(io) #:nodoc
      @wrapped.do_write(io)
    end

    def do_num_bytes #:nodoc:
      @wrapped.do_num_bytes
    end

    #---------------
    private

    def extract_args(args)
      klass = wrapped_class
      if klass
        klass.arg_extractor.extract(klass, args)
      else
        super
      end
    end

    def wrapped_class
      return nil if self.class.field.nil?

      begin
        RegisteredClasses.lookup(self.class.field.type, self.class.endian)
      rescue BinData::UnRegisteredTypeError
        nil
      end
    end
  end
end
