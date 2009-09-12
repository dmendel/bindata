load_failed = false

begin
  require 'haml'
rescue LoadError
  puts "Haml must be installed to build documentation"
  load_failed = true
end

begin
  require 'maruku'
rescue LoadError
  puts "Maruku must be installed to build documentation"
  load_failed = true
end

begin
  require 'syntax'
rescue LoadError
  puts "Syntax must be installed to build documentation"
  load_failed = true
end

unless load_failed
  file "index.html" => ["README", "index.haml"] do |t|
    require 'haml/exec'

    opts = Haml::Exec::Haml.new(["index.haml", "index.html"])
    opts.parse!
  end

  CLOBBER.include("index.html")

  desc "Build the reference manual"
  task :doc => "index.html"
end
