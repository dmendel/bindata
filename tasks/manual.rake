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
  file "doc/manual.html" => ["doc/manual.md", "doc/manual.haml"] do |t|
    require 'haml/exec'

    opts = Haml::Exec::Haml.new(["doc/manual.haml", "doc/manual.html"])
    opts.parse!
  end

  CLOBBER.include("doc/manual.html")

  desc "Build the reference manual"
  task :manual => "doc/manual.html"
end
