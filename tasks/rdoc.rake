require 'rdoc/task'

Rake::RDocTask.new() do |rdoc|
  rdoc.main = "NEWS"
  rdoc.rdoc_files.include("NEWS")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

