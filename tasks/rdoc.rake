require 'rake/rdoctask'

Rake::RDocTask.new() do |rdoc|
  rdoc.main = "README"
  rdoc.rdoc_files.include("README", "NEWS")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

