$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'bindata'
require 'rake/clean'

CURRENT_VERSION = BinData::VERSION

PKG_FILES = FileList[
  "[A-Z]*",
  "examples/**/*",
  "{spec,lib}/**/*.rb",
  "tasks/**/*.rake",
  "setup.rb",
  "manual.haml",
  "manual.md"
]

task :default => :spec

Dir['tasks/**/*.rake'].each { |t| load t }
