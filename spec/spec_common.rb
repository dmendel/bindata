$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

begin
  require 'rubygems'
  gem 'rspec', '> 1.0.0'
rescue LoadError
end

require 'spec'
require 'stringio'

class Object
  def self.expose_methods_for_testing
    private_method_names = self.private_instance_methods - Object.private_instance_methods
    public(*private_method_names.collect { |m| m.to_sym })

    protected_method_names = self.protected_instance_methods - Object.protected_instance_methods
    public(*protected_method_names.collect { |m| m.to_sym })
  end
end
