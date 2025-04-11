require 'rubygems'

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
end

require 'minitest/autorun'
require 'stringio'

$LOAD_PATH.unshift File.expand_path("../lib", File.dirname(__FILE__))
require 'bindata'

class StringIO
  # Returns the value that was written to the io
  def value
    rewind
    read
  end
end

module Kernel
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

module Minitest::Assertions
  def assert_equals_binary(expected, actual)
    assert_equal expected.dup.force_encoding(Encoding::BINARY), actual
  end

  def assert_raises_on_line(exp, line, msg = nil, &block)
    ex = assert_raises(exp, &block)
    assert_equal(msg, ex.message) if msg

    line_num_regex = /(.*):(\d+)(:in.*)$/

    filename = line_num_regex.match(ex.backtrace[0])[1]

    filtered = ex.backtrace.grep(/^#{Regexp.escape(filename)}/)
    top = filtered.grep(Regexp.new(Regexp.escape("in <top (required)>")))

    err_line = line_num_regex.match(filtered[0])[2].to_i
    ref_line = line_num_regex.match(top[0])[2].to_i - 1

    assert_equal((err_line - ref_line), line)
  end

  def assert_warns(msg, &block)
    result = ""
    callable = proc { |str|
      result = str
    }
    Kernel.stub(:warn, callable) do
      block.call
    end

    assert_equal msg, result
  end
end

module Minitest::Expectations
  infect_an_assertion :assert_equals_binary, :must_equal_binary
  infect_an_assertion :assert_raises_on_line, :must_raise_on_line, :block
  infect_an_assertion :assert_warns, :must_warn, :block
end
