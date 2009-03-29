module BinData
  # Executes +block+, writing trace information to +io+.
  # This is useful for debugging a BinData declaration.
  def trace_reading(io = STDERR, &block)
    @trace_io ||= nil
    @saved_io = @trace_io
    @trace = true
    @trace_io = io
    block.call
  ensure
    @trace = false
    @trace_io = @saved_io
  end

  def trace_message(msg) #:nodoc:
    @trace_io ||= nil
    @trace_io.puts(msg) if @trace_io
  end

  module_function :trace_reading, :trace_message
end
