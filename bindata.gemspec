$:.unshift '../lib'
require 'rubygems'
require 'bindata'

spec = Gem::Specification.new do |s|
  s.name = 'bindata'
  s.version = BinData::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'A declarative way to read and write binary file formats'
  s.author = 'Dion Mendel'
  s.email = 'dion@lostrealm.com'
  s.homepage = 'http://bindata.rubyforge.org'
  s.rubyforge_project = 'bindata'

  s.require_path = 'lib'
  s.autorequire = 'bindata'

  s.has_rdoc = true
  s.rdoc_options = %w[README lib/bindata -m README]

  s.files = Dir.glob("[A-Z]*") +  Dir.glob("{examples,spec,lib}/**/*")
end

if $0==__FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end

