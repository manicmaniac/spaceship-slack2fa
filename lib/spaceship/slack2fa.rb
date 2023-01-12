# frozen_string_literal: true

require "json"
require "open-uri"
require "slack"
require "spaceship"
require_relative "slack2fa/version"

module Spaceship
  module Slack2fa
    # Applies monkey patch to {Spaceship::Client} so that it retrieves 6-digit code from Slack.
    #
    # The monkey patch is only enabled in the given block scope.
    #
    # @option options [String] :slack_api_token
    # @option options [String] :channel_id
    # @option options [String] :user_id
    # @option options [Integer] :retry_count
    # @option options [Float] :retry_interval
    def self.enable(**options)
      patch = MonkeyPatch.new(**options)
      patch.enable
      begin
        yield
      ensure
        patch.disable
      end
    end

    class MonkeyPatch
      def initialize(**options)
        @slack_api_token = options.fetch(:slack_api_token)
        @channel_id = options.fetch(:channel_id)
        @user_id = options.fetch(:user_id)
        @retry_count = options.fetch(:retry_count, 3)
        @retry_interval = options.fetch(:retry_interval, 20.0)
      end

      def enable
        Spaceship::Client.alias_method(:original_ask_for_2fa_code, :ask_for_2fa_code)
        Spaceship::Client.define_method(:ask_for_2fa_code, &public_method(:retrieve_2fa_code))
      end

      def disable
        Spaceship::Client.alias_method(:ask_for_2fa_code, :original_ask_for_2fa_code)
      end

      def retrieve_2fa_code(*_args)
        slack = Slack::Web::Client.new(token: @slack_api_token)
        (@retry_count + 1).times do |_i|
          response = slack.conversations_history(channel: @channel_id)
          unused_2fa_codes = response.messages.select { |message| unused_2fa_code?(message) }
          message = unused_2fa_codes.max_by(&:ts)
          code = message&.text
          return code if code

          sleep(@retry_interval)
        end
      end

      private

      def unused_2fa_code?(message)
        message.type == "message" &&
          message.user == @user_id &&
          (message.reply_count || 0) == 0 &&
          (message.reactions || []).empty? &&
          (message.text || "") =~ /^\d{6}$/
      end
    end
  end
end
