# BinData -- Binary data manipulator.
# Copyright (c) 2007,2008 Dion Mendel.

require 'bindata/array'
require 'bindata/bits'
require 'bindata/choice'
require 'bindata/float'
require 'bindata/int'
require 'bindata/multi_value'
require 'bindata/rest'
require 'bindata/single_value'
require 'bindata/string'
require 'bindata/stringz'
require 'bindata/struct'

# = BinData
# 
# A declarative way to read and write structured binary data.
# 
module BinData
  VERSION = "0.9.3"

  def trace_read(io = STDERR, &block)
    @trace_io ||= nil
    @saved_io = @trace_io
    @trace = true
    @trace_io = io
    block.call
  ensure
    @trace = false
    @trace_io = @saved_io
  end

  def trace_message(msg)
    @trace_io ||= nil
    @trace_io.puts(msg) if @trace_io
  end

  module_function :trace_read, :trace_message
end
