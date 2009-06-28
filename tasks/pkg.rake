begin
  require 'rubygems'
  require 'rake/gempackagetask'

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
    s.extra_rdoc_files = ['README']
    s.rdoc_options << '--main' << 'README'
    s.files = PKG_FILES
  end

  Rake::GemPackageTask.new(SPEC) do |pkg|
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
