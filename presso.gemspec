$: << File.expand_path('../lib', __FILE__)

require 'presso'

Gem::Specification.new do |s|
  s.name        = 'presso'
  s.version     = Presso::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Burt Developers']
  s.email       = ['bjorn@burtcorp.com']
  s.homepage    = 'https://github.com/burtcorp/presso'
  s.summary     = 'A zip library for JRuby'
  s.description = 'Easy zip and unzip, backed by java.util.zip'
  s.files         = Dir['lib/presso.rb']
  s.require_paths = ['lib']
end
