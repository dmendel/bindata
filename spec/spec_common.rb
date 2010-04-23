$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

begin
  require 'rubygems'
  gem 'rspec', '> 1.2.2'
rescue LoadError
end

require 'spec'
require 'spec/autorun'
require 'stringio'

class Object
  def expose_methods_for_testing
    cls = (Class === self) ? self : (class << self ; self; end)
    private_method_names = cls.private_instance_methods - Object.private_instance_methods
    cls.send(:public, *private_method_names)

    protected_method_names = cls.protected_instance_methods - Object.protected_instance_methods
    cls.send(:public, *protected_method_names)
  end
end

class StringIO
  # Returns the value that was written to the io
  def value
    rewind
    read
  end
end
