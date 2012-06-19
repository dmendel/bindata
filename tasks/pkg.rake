begin
  require 'rubygems'
  require 'rubygems/package_task'

  SPEC = Gem::Specification.new do |s|
    s.name = 'bindata'
    s.version = CURRENT_VERSION
    s.platform = Gem::Platform::RUBY
    s.summary = 'A declarative way to read and write binary file formats'
    s.author = 'Dion Mendel'
    s.email = 'dion@lostrealm.com'
    s.homepage = 'http://bindata.rubyforge.org'
    s.rubyforge_project = 'bindata'
    s.require_path = 'lib'
    s.has_rdoc = true
    s.extra_rdoc_files = ['NEWS']
    s.rdoc_options << '--main' << 'NEWS'
    s.files = PKG_FILES
    s.add_development_dependency('rspec', [">= 2.10.0"])
    s.add_development_dependency('haml')
    s.add_development_dependency('maruku')
    s.add_development_dependency('syntax')
    s.description = <<-END.gsub(/^ +/, "")
      BinData is a declarative way to read and write binary file formats.

      This means the programmer specifies *what* the format of the binary
      data is, and BinData works out *how* to read and write data in this
      format.  It is an easier ( and more readable ) alternative to
      ruby's #pack and #unpack methods.
    END
  end

  Gem::PackageTask.new(SPEC) do |pkg|
    pkg.need_tar_gz = true
  end

  file "bindata.gemspec" => ["Rakefile", "lib/bindata.rb"] do |t|
    require 'yaml'
    open(t.name, "w") { |f| f.puts SPEC.to_yaml }
  end

  CLOBBER.include("bindata.gemspec")

  desc "Create a stand-alone gemspec"
  task :gemspec => "bindata.gemspec"
rescue LoadError
  puts "RubyGems must be installed to build the package"
end
