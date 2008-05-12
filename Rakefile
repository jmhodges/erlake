require 'rubygems'
require 'rake/gempackagetask'
require 'erlake'

spec = Gem::Specification.load("erlake.gemspec")

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = false
end