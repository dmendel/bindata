$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'bindata/version'

Gem::Specification.new do |s|
  s.name = 'bindata'
  s.version = BinData::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'A declarative way to read and write binary file formats'
  s.author = 'Dion Mendel'
  s.email = 'bindata@dmau.org'
  s.homepage = 'https://github.com/dmendel/bindata'
  s.require_path = 'lib'
  s.extra_rdoc_files = ['NEWS.rdoc']
  s.rdoc_options << '--main' << 'NEWS.rdoc'
  s.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.start_with?(*%w[.git INSTALL])
    end
  end
  s.license = 'BSD-2-Clause'
  s.required_ruby_version = ">= 2.5.0"

  s.add_development_dependency('rake')
  s.add_development_dependency('minitest', "> 5.0.0")
  s.add_development_dependency('simplecov')
  s.description = <<-END.gsub(/^ +/, "")
    BinData is a declarative way to read and write binary file formats.

    This means the programmer specifies *what* the format of the binary
    data is, and BinData works out *how* to read and write data in this
    format.  It is an easier ( and more readable ) alternative to
    ruby's #pack and #unpack methods.
  END
  s.metadata['changelog_uri'] = s.homepage + '/blob/master/ChangeLog.rdoc'
end
