$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

begin
  require 'rubygems'
  gem 'rspec', '> 0.8.0'
rescue LoadError
end

require 'spec'
require 'stringio'
