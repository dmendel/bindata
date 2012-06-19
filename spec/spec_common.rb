$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

require 'rspec'
require 'rspec/autorun'
require 'stringio'

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

def exception_line(ex)
  idx = ex.backtrace.find_index { |bt| /:in `should'$/ =~ bt }

  if idx
    line_num_regex = /.*:(\d+)(:.*|$)/

    err_line = line_num_regex.match(ex.backtrace[0])[1].to_i
    ref_line = line_num_regex.match(ex.backtrace[idx + 1])[1].to_i

    err_line - ref_line
  else
    raise "Required calling pattern is lambda { xxx }.should raise_error_on_line(...)"
  end
end

def raise_error_on_line(exception, line, &block)
  raise_exception(exception) do |err|
    exception_line(err).should == line
    block.call(err) if block_given?
  end
end

