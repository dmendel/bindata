begin
  require 'spec'
  require 'spec/rake/spectask'

  Spec::Rake::SpecTask.new("spec") do |t|
    t.warning = false
    t.rcov = false
    t.spec_files = FileList['spec/**/*_spec.rb'].exclude("spec/deprecated_spec.rb", "spec/wrapper_spec.rb")
  end

  Spec::Rake::SpecTask.new("rcov") do |t|
    t.warning = true
    t.rcov = true
  end
rescue LoadError
  puts "Rspec must be installed to run tests"
end
