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
  #     array :type => [:uint8, {:initial_value => :initial_element_value}],
  #           :initial_length => 2
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

    def initialize(parameters = {}, parent = nil)
      super

      prototype = get_parameter(:wrapped)
      @wrapped = prototype.instantiate(self)
    end

    def clear #:nodoc:
      wrapped.clear
    end

    def clear? #:nodoc:
      wrapped.clear?
    end

    def respond_to?(symbol, include_private = false) #:nodoc:
      wrapped.respond_to?(symbol, include_private) || super
    end

    def method_missing(symbol, *args, &block) #:nodoc:
      wrapped.__send__(symbol, *args, &block)
    end

    #---------------
    private

    def wrapped
      @wrapped
    end

    def _do_read(io)
      wrapped.do_read(io)
    end

    def _do_write(io)
      wrapped.do_write(io)
    end

    def _do_num_bytes
      wrapped.do_num_bytes
    end

    def _assign(val)
      wrapped.assign(val)
    end

    def _snapshot
      wrapped.snapshot
    end
  end
end
