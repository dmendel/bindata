begin
  require 'rspec'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new("spec") do |t|
#    t.ruby_opts = "-w"
    t.rcov = false
    t.pattern = 'spec/**/*_spec.rb' #.exclude("spec/deprecated_spec.rb", "spec/wrapper_spec.rb")
  end

  RSpec::Core::RakeTask.new("rcov") do |t|
    t.ruby_opts = "-w"
    t.rcov = true
  end
rescue LoadError
  puts "Rspec must be installed to run tests"
end
