# frozen_string_literal: true

require_relative 'lib/spaceship/slack2fa/version'

Gem::Specification.new do |spec|
  spec.name = 'spaceship-slack2fa'
  spec.version = Spaceship::Slack2fa::VERSION
  spec.authors = ['Ryosuke Ito']
  spec.email = ['rito.0305@gmail.com']
  spec.summary = 'A hacky fastlane plugin to retrieve 2FA code from Slack channel.'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/manicmaniac/spaceship-slack2fa'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'fastlane', '~> 2.0'
  spec.add_dependency 'slack-ruby-client', '~> 1.0'
end
