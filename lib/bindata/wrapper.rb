require 'bindata/base'
require 'bindata/dsl'

module BinData
  class SanitizedParameters < Hash
    def move_unknown_parameters_to(dest)
      unused_keys = keys - @the_class.accepted_parameters.all
      unused_keys.each do |key|
        dest[key] = delete(key)
      end
    end
  end

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

    unregister_self
    dsl_parser :wrapper

    class << self
      def sanitize_parameters!(params) #:nodoc:
        raise "no wrapped type was specified in #{self}" if fields[0].nil?

        wrapped_type = fields[0].type
        wrapped_params = fields[0].params.dup

        params.move_unknown_parameters_to(wrapped_params)

        params.endian = endian unless endian.nil?
        params[:wrapped] = params.create_sanitized_object_prototype(wrapped_type, wrapped_params)

        wrapped_class = params[:wrapped].instance_variable_get(:@obj_class)
        warn "BinData::Wrapper is deprecated as of BinData 1.3.2.  #{self} should derive from #{wrapped_class}\n   See http://bindata.rubyforge.org/#extending_existing_types"
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
      return nil if self.class.fields[0].nil?

      begin
        RegisteredClasses.lookup(self.class.fields[0].type, self.class.endian)
      rescue BinData::UnRegisteredTypeError
        nil
      end
    end
  end
end
