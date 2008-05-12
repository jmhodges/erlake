require 'rubygems'
require 'rake/gempackagetask'
require 'erlake'

spec = Gem::Specification.new do |s|
  s.name       = "erlake"
  s.version    = Erlake::Version
  s.author     = "Jeff Hodges"
  s.email      = "jeff at somethingsimilar dot com"
  # s.homepage   = "http://rfeedparser.rubyforge.org/"
  s.platform   = Gem::Platform::RUBY
  s.summary    = "A rake task library for Erlang projects"
  s.files      = FileList["erlake.rb", "examples/*"].exclude("rdoc").to_a
  # s.autorequire       = "feedparser" # tHe 3vil according to Why.
  s.has_rdoc          = false # TODO: fix
  # s.rubyforge_project = 'erlake'
  s.require_path = ''
  # Dependencies
  s.add_dependency('rake', '>=0.8.1')
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = false
end