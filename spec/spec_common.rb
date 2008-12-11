$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

begin
  require 'rubygems'
  gem 'rspec', '> 1.0.0'
rescue LoadError
end

require 'spec'
require 'stringio'

class Object
  def self.make_private_instance_methods_public
    private_method_names = self.private_instance_methods - Object.private_instance_methods
    public(*private_method_names.collect { |m| m.to_sym })
  end
end
