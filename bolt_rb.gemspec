# bolt_rb.gemspec
require_relative 'lib/bolt_rb/version'

Gem::Specification.new do |spec|
  spec.name          = 'bolt_rb'
  spec.version       = BoltRb::VERSION
  spec.authors       = ['Your Name']
  spec.email         = ['your@email.com']

  spec.summary       = 'A bolt-js inspired framework for building Slack bots in Ruby'
  spec.description   = 'Provides a clean DSL for handling Slack events, commands, actions, and shortcuts using Socket Mode'
  spec.homepage      = 'https://github.com/slackapi/bolt-rb'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files = Dir.glob('{lib}/**/*') + %w[README.md LICENSE.txt]
  spec.require_paths = ['lib']

  spec.add_dependency 'slack-ruby-client', '~> 3.0'
  spec.add_dependency 'websocket-client-simple', '~> 0.9'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'webmock', '~> 3.18'
end
