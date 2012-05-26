require "./lib/stewiki/version"

Gem::Specification.new do |s|
  s.name = "stewiki"
  s.version = Stewiki::VERSION
  s.summary = %{A git based personal wiki engine}
  s.description = %Q{Stewiki is a simple personal wiki engine which runs as a Sinatra app, uses Markdown for content and Git for page storage/versioning.}
  s.authors = ["Phil Stewart"]
  s.email = ["phil.stewart@lichp.co.uk"]
  s.homepage = "http://github.com/lichp/stewiki"

  s.files = Dir[
    "lib/**/*.rb",
    "lib/stewiki/server/**/*",
    "bin/*",
    "README*",
    "LICENSE",
    "Rakefile",
    "config.ru"
  ]

  s.bindir = 'bin'
  s.executables = 'stewiki'

  s.add_dependency "sinatra", ">= 1.2"
  s.add_dependency "haml", ">= 3.1"
  s.add_dependency "grit", ">= 2.4"
  s.add_dependency "redcarpet", ">= 1.17"
  s.add_dependency "shield", ">= 0.1"
  s.add_dependency "rack-flash3", ">= 1.0"
  s.add_dependency "scrivener", ">= 0.0.3"
end
