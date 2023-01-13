# frozen_string_literal: true

RSpec.describe Spaceship::Slack2fa do
  it "has a version number" do
    expect(Spaceship::Slack2fa::VERSION).not_to be nil
  end

  describe ".enable" do
    subject do
      described_class.enable(**options) { client.ask_for_2fa_code }
    end

    let(:client) { Spaceship::TunesClient.new }
    let(:options) do
      {
        slack_api_token: 'SLACK_API_TOKEN',
        channel_id: 'CHANNEL_ID',
        user_id: 'U012AB3CDE',
        referrer: 'REFERRER',
        retry_count: retry_count,
        retry_interval: 0.1,
      }
    end
    let(:retry_count) { 0 }
    let(:slack) { instance_double(Slack::Web::Client) }

    before do
      Spaceship::Client.define_method(:ask_for_2fa_code) { raise NotImplementedError }
      allow(Slack::Web::Client).to receive(:new)
        .with(token: "SLACK_API_TOKEN")
        .and_return slack
    end

    context "when authenticated" do
      before do
        json_path = File.expand_path("../support/fixtures/conversations.history.json", __dir__)
        json = JSON.parse(File.read(json_path))
        allow(slack).to receive(:conversations_history)
          .with(channel: "CHANNEL_ID")
          .and_return Slack::Messages::Message.new(json)
        allow(slack).to receive(:chat_postMessage)
      end

      it "retrieves 2FA code from Slack messages" do
        expect(subject).to eq "123456"
      end

      it "posts a comment on the thread" do
        subject
        expect(slack).to have_received(:chat_postMessage)
          .with(channel: "CHANNEL_ID",
                text: a_string_including("REFERRER"),
                thread_ts: "1512104434.000490")
      end

      it "removes temporary method" do
        subject
        expect(client).not_to respond_to :original_ask_for_2fa_code
      end
    end

    context "when channel.history is missing in scope" do
      before do
        allow(slack).to receive(:conversations_history)
          .and_raise Slack::Web::Api::Errors::MissingScope.new("missing scope")
      end

      it "raises an error" do
        expect { subject }.to raise_error Slack::Web::Api::Errors::MissingScope
      end
    end

    context "when chat.write is missing in scope" do
      before do
        json_path = File.expand_path("../support/fixtures/conversations.history.json", __dir__)
        json = JSON.parse(File.read(json_path))
        allow(slack).to receive(:conversations_history)
          .with(channel: "CHANNEL_ID")
          .and_return Slack::Messages::Message.new(json)
        allow(slack).to receive(:chat_postMessage)
          .and_raise Slack::Web::Api::Errors::MissingScope.new("missing scope")
      end

      it "logs an error without raising it" do
        expect { subject }.to output(/missing scope/).to_stderr
        expect(slack).to have_received(:chat_postMessage)
          .with(channel: "CHANNEL_ID",
                text: a_string_including("REFERRER"),
                thread_ts: "1512104434.000490")
      end
    end

    context "when authentication failed" do
      before do
        allow(slack).to receive(:conversations_history)
          .and_raise Slack::Web::Api::Errors::InvalidAuth.new("invalid_auth")
      end

      it "raises RuntimeError" do
        expect { subject }.to raise_error Slack::Web::Api::Errors::InvalidAuth
      end
    end
  end
end
