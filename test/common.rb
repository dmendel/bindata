require 'rubygems'

require 'coveralls'
Coveralls.wear!

require 'minitest/autorun'
require 'stringio'

$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
require 'bindata'

class Object
  def expose_methods_for_testing
    cls = (Class === self) ? self : (class << self ; self; end)
    private_method_names = cls.private_instance_methods - Object.private_instance_methods
    cls.send(:public, *private_method_names)

    protected_method_names = cls.protected_instance_methods - Object.protected_instance_methods
    cls.send(:public, *protected_method_names)
  end

  def value_read_from_written
    self.class.read(self.to_binary_s)
  end
end

class StringIO
  # Returns the value that was written to the io
  def value
    rewind
    read
  end
end

class ExampleSingle < BinData::BasePrimitive
  def self.io_with_value(val)
    StringIO.new([val].pack("V"))
  end

  private

  def value_to_binary_string(val)
    [val].pack("V")
  end

  def read_and_return_value(io)
    io.readbytes(4).unpack("V").at(0)
  end

  def sensible_default
    0
  end
end

def binary(str)
  str.dup.force_encoding(Encoding::BINARY)
end

module Kernel
  def must_raise_on_line(exp, line, msg = nil)
    ex = self.must_raise exp
    ex.message.must_equal msg if msg

    idx = ex.backtrace.find_index { |bt| /:in `must_raise_on_line'$/ =~ bt }

    line_num_regex = /.*:(\d+)(:.*|$)/
    err_line = line_num_regex.match(ex.backtrace[0])[1].to_i
    ref_line = line_num_regex.match(ex.backtrace[idx + 1])[1].to_i

    (err_line - ref_line).must_equal line
  end
end

