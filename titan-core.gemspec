$:.push File.expand_path("../lib", __FILE__)
require 'titan-core/version'

Gem::Specification.new do |s|
  s.name     = 'titan-core'
  s.version  = Titan::Core::VERSION
  s.required_ruby_version = '>= 1.9.3'

  s.authors  = 'Reza Ghorbani Farid'
  s.email    = 'r.ghorbani.f@gmail.com'
  s.homepage = 'https://github.com/rghorbani/titan-core'
  s.summary  = 'A basic library to work with the graph database Titan.'
  s.license  = 'MIT'

  s.description = 'Titan-core provides classes and methods to work with the graph database Titan.'

  s.require_path = ['lib']
  s.files = Dir.glob('{bin,lib,config}/**/*') + %w(README.md Gemfile titan-core.gemspec)
  s.has_rdoc = true
  s.extra_rdoc_files = %w( README.md )
  s.rdoc_options = ['--quiet', '--title', 'Titan::Core', '--line-numbers', '--main', 'README.rdoc', '--inline-source']

  s.add_dependency('httparty')
  s.add_dependency('faraday', '~> 0.9.0')
  s.add_dependency('net-http-persistent')
  s.add_dependency('httpclient')
  s.add_dependency('faraday_middleware', '~> 0.9.1')
  s.add_dependency('json')
  s.add_dependency('activesupport') # For ActiveSupport::Notifications
  s.add_dependency('multi_json')
  s.add_dependency('faraday_middleware-multi_json')

  s.add_development_dependency('pry')
  s.add_development_dependency('yard')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('guard')
  s.add_development_dependency('guard-rubocop')
  s.add_development_dependency('rubocop', '~> 0.29.1')

  if RUBY_PLATFORM == 'java'
    s.add_dependency('titan-jars')
    s.add_development_dependency ('ruby-debug')
  end
end
