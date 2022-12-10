# frozen_string_literal: true

require "json"
require "open-uri"
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
        code = nil
        until code || @retry_count < 0
          @retry_count -= 1
          response = ::URI.parse("https://slack.com/api/conversations.history?channel=#{@channel_id}").open(
            "Authorization" => "Bearer #{@slack_api_token}"
          )
          json = ::JSON.load(response)
          unless json["ok"]
            message = json.fetch("error")
            raise "#{message}; See https://api.slack.com/methods/conversations.history for details."
          end
          candidate_messages = json["messages"].select do |message|
            (message["type"] == "message" &&
            message["user"] == @user_id &&
            message.fetch("reply_count", 0) == 0 &&
            message.fetch("reactions", []).empty? &&
            message["text"] =~ /^\d{6}$/)
          end
          message = candidate_messages.max_by { |message| message["ts"] }
          code = message&.fetch("text", nil)
          sleep(@retry_interval) unless code
        end
        code
      end
    end
  end
end
