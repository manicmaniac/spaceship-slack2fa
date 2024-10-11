# frozen_string_literal: true

require 'logger'
require 'json'
require 'open-uri'
require 'slack'
require 'spaceship'
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
    # An exception raised when 2FA code is not found after retries.
    # Do not retry after this error, otherwise your account will be locked.
    # See https://github.com/manicmaniac/spaceship-slack2fa/issues/59 for the detail.
    class VerificationCodeNotFound < StandardError
      def message
        '2FA code was sent but not found in Slack. Please make sure your code is successfully sent.'
      end
    end

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

    # @api private
    class MonkeyPatch
      REQUIRED_SLACK_SCOPES = %w[channels.history chat.write].freeze

      # @option options [String] :slack_api_token          Required. A bot token for your Slack app.
      # @option options [String] :channel_id               Required. The ID of the channel where the message will be
      #                                                    posted.
      # @option options [String] :user_id                  Required. The ID of the user posting the message.
      # @option options [String] :referrer                 Required. A +mrkdwn+ text to identify which service consumes
      #                                                    6-digit code, typically the name of your app.
      # @option options [Boolean] :allow_any_users (false) Optional. If `true`, `spaceship-slack2fa` recognizes only
      #                                                    messages from the bot user specified in `slack_api_token`,
      #                                                    otherwise it treats all messages with 6-digits numbers as
      #                                                    2FA code. The default is `false`.
      # @option options [Integer] :retry_count (3)         Optional. The number of retries to try if a message is not
      #                                                    found.
      # @option options [Float] :retry_interval (20)       Optional. The interval between retries in seconds.
      #
      # @see https://stackoverflow.com/a/44883343/6918498
      #      What is the simplest way to find a slack team ID and a channel ID?
      def initialize(**options)
        slack_api_token = options.fetch(:slack_api_token)
        @slack = Slack::Web::Client.new(token: slack_api_token)
        @channel_id = options.fetch(:channel_id)
        @user_id = options.fetch(:user_id)
        @referrer = options.fetch(:referrer)
        @allow_any_users = options.fetch(:allow_any_users, false)
        @retry_count = options.fetch(:retry_count, 3)
        @retry_interval = options.fetch(:retry_interval, 20.0)
        @logger = Logger.new($stderr)
        @logger.level = (options.fetch(:verbose, false) ? Logger::DEBUG : Logger::WARN)
      end

      def enable
        Spaceship::Client.alias_method(:original_ask_for_2fa_code, :ask_for_2fa_code)
        Spaceship::Client.define_method(:ask_for_2fa_code, &public_method(:retrieve_2fa_code))
      end

      def disable
        Spaceship::Client.alias_method(:ask_for_2fa_code, :original_ask_for_2fa_code)
        Spaceship::Client.remove_method(:original_ask_for_2fa_code)
      end

      def retrieve_2fa_code(*_args)
        timestamp = Time.now.to_i
        with_retrying do |i|
          @logger.debug("Attempt ##{i}.")
          response = @slack.conversations_history(channel: @channel_id, oldest: timestamp)
          @logger.debug("Found #{response.messages.size} messages.")
          message = response.messages.select { |msg| unused_2fa_code?(msg) }.max_by(&:ts)
          @logger.debug("Possible message: #{message}.")
          code = message&.text
          if code
            @logger.debug("Found 2FA code: #{code}.")
            comment_on_thread_of(message)
            return code
          end
        end
        raise VerificationCodeNotFound
      end

      private

      def with_retrying
        (@retry_count + 1).times do |i|
          yield i
          sleep(@retry_interval)
        end
      end

      def comment_on_thread_of(message)
        url = 'https://github.com/manicmaniac/spaceship-slack2fa'
        text = "This 6-digit token has been consumed by #{@referrer} using <#{url}|spaceship-slack2fa>."
        @slack.chat_postMessage(channel: @channel_id, text: text, thread_ts: message.ts, unfurl_links: false)
      rescue Slack::Web::Api::Errors::MissingScope => e
        @logger.warn("#{e.full_message}Make sure your Slack app has #{REQUIRED_SLACK_SCOPES} in the scope.")
      end

      def unused_2fa_code?(message)
        message.type == 'message' &&
          (@allow_any_users || message.user == @user_id) &&
          message.fetch('reply_count', 0).zero? &&
          message.fetch('reactions', []).empty? &&
          message.fetch('text', '') =~ /^\d{6}$/
      end
    end
  end
end
