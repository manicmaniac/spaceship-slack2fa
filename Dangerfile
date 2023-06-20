# frozen_string_literal: true

require 'bundler'

rubocop.lint inline_comment: true

lockfile_path = Bundler.default_lockfile
gemspec_path = 'spaceship-slack2fa.gemspec'
unless (git.modified_files & [gemspec_path, lockfile_path, 'lib/spaceship/slack2fa/version.rb']).empty?
  lockfile = Bundler::LockfileParser.new(Bundler.read_file(lockfile_path))
  lockfile_spec = lockfile.specs.detect { |spec| spec.name == 'spaceship-slack2fa' }
  gemspec = Bundler.load_gemspec(gemspec_path)

  if lockfile_spec.version != gemspec.version
    fail(<<~ERROR)
      #{lockfile_path} declares spaceship-slack2fa should be #{lockfile_spec.version}" but \
      #{gemspec_path} declares it should be #{gemspec.version}.
      Run `bundle install` to update version of #{lockfile_path}.
    ERROR
  end
end
