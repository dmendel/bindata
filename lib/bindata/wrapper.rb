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

    register_subclasses

    class << self

      def endian(endian = nil)
        @endian ||= default_endian
        if [:little, :big].include?(endian)
          @endian = endian
        elsif endian != nil
          raise ArgumentError,
                  "unknown value for endian '#{endian}' in #{self}", caller(1)
        end
        @endian
      end

      def wrapped(*args)
        @wrapped ||= default_wrapped
        if args.length == 2
          type, params = *args
          ensure_type_exists(type)

          if wrapped != nil
            raise SyntaxError, "#{self} can only wrap one type", caller(2)
          end
          @wrapped = [type, params]
        end
        @wrapped
      end

      def method_missing(symbol, *args) #:nodoc:
        type = symbol
        params = args.length == 0 ? {} : args[0]

        wrapped(type, params)
      end

      def sanitize_parameters!(params, sanitizer) #:nodoc:
        raise "Nothing to wrap" if wrapped.nil?

        wrapped_type, wrapped_params = wrapped
        wrapped_params = wrapped_params.dup

        params.move_unknown_parameters_to(wrapped_params)

        params[:wrapped] = sanitizer.create_sanitized_object_prototype(wrapped_type, wrapped_params, endian)
      end

      #-------------
      private

      def parent_wrapper
        ancestors[1..-1].find { |cls|
          cls.ancestors[1..-1].include?(BinData::Wrapper)
        }
      end

      def default_endian
        wrap = parent_wrapper
        wrap ? wrap.endian : nil
      end

      def default_wrapped
        wrap = parent_wrapper
        wrap ? wrap.wrapped : nil
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

    def clear #:nodoc:
      wrapped.clear
    end

    def clear? #:nodoc:
      wrapped.clear?
    end

    def respond_to?(symbol, include_private = false) #:nodoc:
      super || wrapped.respond_to?(symbol, include_private)
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

    def _done_read
      wrapped.done_read
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
