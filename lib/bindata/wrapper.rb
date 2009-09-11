require 'bindata/base'

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

    class << self

      def inherited(subclass) #:nodoc:
        # Register the names of all subclasses of this class.
        register(subclass.name, subclass)
      end

      def endian(endian = nil)
        @endian ||= nil
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError,
                  "unknown value for endian '#{endian}' in #{self}", caller(1)
        end
        @endian
      end

      def method_missing(symbol, *args)
        type = symbol
        params = args.length == 0 ? {} : args[0]

        set_wrapped(type, params)
      end

      def sanitize_parameters!(params, sanitizer)
        raise "Nothing to wrap" unless defined? @wrapped

        wrapped_type, wrapped_params = @wrapped
        wrapped_params = wrapped_params.dup

        params.move_unknown_parameters_to(wrapped_params)

        params[:wrapped] = sanitizer.create_sanitized_object_prototype(wrapped_type, wrapped_params, endian)
      end

      #-------------
      private

      def set_wrapped(type, params)
        ensure_type_exists(type)

        if defined? @wrapped
          raise SyntaxError, "#{self} can only wrap one type", caller(2)
        end
        @wrapped = [type, params]
      end

      def ensure_type_exists(type)
        unless RegisteredClasses.is_registered?(type, endian)
          raise TypeError, "unknown type '#{type}' for #{self}", caller(3)
        end
      end
    end

    def initialize(params = {}, parent = nil)
      super(params, parent)

      prototype = get_parameter(:wrapped)
      @wrapped = prototype.instantiate(self)
    end

    def clear
      wrapped.clear
    end

    def clear?
      wrapped.clear?
    end

    def respond_to?(symbol, include_private = false)
      super || wrapped.respond_to?(symbol, include_private)
    end

    def method_missing(symbol, *args, &block)
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

    def _done_read
      wrapped.done_read
    end

    def _do_write(io)
      wrapped.do_write(io)
    end

    def _do_num_bytes(deprecated)
      wrapped.do_num_bytes(deprecated)
    end

    def _assign(val)
      wrapped.assign(val)
    end

    def _snapshot
      wrapped.snapshot
    end
  end
end
