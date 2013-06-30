require 'bundler'
Bundler.setup
Bundler::GemHelper.install_tasks

require 'rake/clean'

task :clobber do
  rm_rf 'pkg'
end

task :default => :spec

Dir['tasks/**/*.rake'].each { |t| load t }
