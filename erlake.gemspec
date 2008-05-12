Gem::Specification.new do |s|
  s.name       = "erlake"
  s.version    = Erlake::Version
  s.author     = "Jeff Hodges"
  s.email      = "jeff at somethingsimilar dot com"

  s.platform   = Gem::Platform::RUBY
  s.summary    = "A rake task library for Erlang projects"
  s.files      = FileList["erlake.rb", "examples/*"].exclude("rdoc").to_a
  s.has_rdoc          = false # TODO: fix
  s.require_path = ''

  # s.rubyforge_project = 'erlake'
  # s.homepage   = "http://rfeedparser.rubyforge.org/"


  s.add_dependency('rake', '>=0.8.1')
end