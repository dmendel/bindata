module BinData
  # reference to the current tracer
  @tracer ||= nil

  class Tracer #:nodoc:
    def initialize(io)
      @trace_io = io
    end

    def trace(msg)
      @trace_io.puts(msg)
    end

    def trace_obj(obj_name, val)
      if val.length > 30
        val = val.slice(0 .. 30) + "..."
      end

      trace "#{obj_name} => #{val}"
    end
  end

  # Turn on trace information when reading a BinData object.
  # If +block+ is given then the tracing only occurs for that block.
  # This is useful for debugging a BinData declaration.
  def trace_reading(io = STDERR, &block)
    @tracer = Tracer.new(io)
    BasePrimitive.turn_on_tracing
    Choice.turn_on_tracing
    if block_given?
      begin
        block.call
      ensure
        BasePrimitive.turn_off_tracing
        Choice.turn_off_tracing
        @tracer = nil
      end
    end
  end

  def trace_message(&block) #:nodoc:
    yield @tracer if @tracer
  end

  module_function :trace_reading, :trace_message

  class BasePrimitive < BinData::Base
    class << self
      def turn_on_tracing
        alias_method :hook_after_do_read, :trace_value
      end

      def turn_off_tracing
        alias_method :hook_after_do_read, :null_method
      end
    end

    #---------------
    private

    def null_method; end

    def trace_value
      BinData::trace_message do |tracer|
        value_string = _value.inspect
        tracer.trace_obj(debug_name, value_string)
      end
    end
  end

  class Choice < BinData::Base
    class << self
      def turn_on_tracing
        alias_method :hook_before_do_read, :trace_selection
      end

      def turn_off_tracing
        alias_method :hook_before_do_read, :null_method
      end
    end

    #---------------
    private

    def null_method; end

    def trace_selection
      BinData::trace_message do |tracer|
        selection_string = eval_parameter(:selection).inspect
        tracer.trace_obj("#{debug_name}-selection-", selection_string)
      end
    end
  end
end
