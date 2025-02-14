# frozen_string_literal: true

require_relative 'slack2fa/monkey_patch'
require_relative 'slack2fa/version'

module Spaceship
  # A module for applying a monkey patch to {https://rubydoc.info/gems/fastlane/Spaceship/Client Spaceship::Client}
  # in the specific scope.
  #
  # @example Simple Fastfile
  #   require "spaceship/slack2fa"
  #
  #   ENV["FASTLANE_USER"] = "user@example.com"
  #   ENV["FASTLANE_PASSWORD"] = "password"
  #   ENV["SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER"] = "+81 80-XXXX-XXXX"
  #
  #   lane :login do
  #     Spaceship::Slack2fa.enable(
  #       slack_api_token: "xoxb-0000000000-0000000000000-XXXXXXXXXXXXXXXXXXXXXXXX",
  #       channel_id: "CXXXXXXXX",
  #       user_id: "UXXXXXXXX",
  #       referrer: "My app"
  #     ) do
  #       Spaceship::TunesClient.login
  #     end
  #   end
  #
  # @example Practical Fastfile
  #   require "spaceship/slack2fa"
  #
  #   ENV["FASTLANE_USER"] = "user@example.com"
  #   ENV["FASTLANE_PASSWORD"] = "password"
  #   ENV["SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER"] = "+81 80-XXXX-XXXX"
  #
  #   lane :release do
  #     enable_slack2fa do
  #       deliver
  #     end
  #   end
  #
  #   lane :beta do
  #     enable_slack2fa do
  #       pilot
  #     end
  #   end
  #
  #   def enable_slack2fa(&block)
  #     Spaceship::Slack2fa.enable(
  #       slack_api_token: "xoxb-0000000000-0000000000000-XXXXXXXXXXXXXXXXXXXXXXXX",
  #       channel_id: "CXXXXXXXX",
  #       user_id: "UXXXXXXXX",
  #       referrer: "My app",
  #       &block
  #     )
  #   end
  module Slack2fa
    # Applies monkey patch to {https://rubydoc.info/gems/fastlane/Spaceship/Client Spaceship::Client} so that it
    # retrieves 6-digit code from Slack.
    #
    # The monkey patch is only enabled in the given block scope.
    #
    # @param options [Hash] All options are passed to {MonkeyPatch#initialize}.
    # @yield A block where the monkey patch is enabled.
    def self.enable(**options)
      patch = MonkeyPatch.new(**options)
      patch.enable
      begin
        yield
      ensure
        patch.disable
      end
    end
  end
end
