# frozen_string_literal: true

RSpec.describe Spaceship::Slack2fa do
  it "has a version number" do
    expect(Spaceship::Slack2fa::VERSION).not_to be nil
  end

  describe ".enable" do
    subject do
      described_class.enable(**options) { Spaceship::TunesClient.new.ask_for_2fa_code }
    end

    let(:options) do
      {
        slack_api_token: 'SLACK_API_TOKEN',
        channel_id: 'CHANNEL_ID',
        user_id: 'U012AB3CDE',
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
          .with(channel: 'CHANNEL_ID')
          .and_return Slack::Messages::Message.new(json)
      end

      it "retrieves 2FA code from Slack messages" do
        expect(subject).to eq "123456"
      end
    end

    context "when authentication failed" do
      before do
        allow(slack).to receive(:conversations_history)
          .with(channel: 'CHANNEL_ID')
          .and_raise Slack::Web::Api::Errors::InvalidAuth.new("invalid_auth")
      end

      it "raises RuntimeError" do
        expect { subject }.to raise_error Slack::Web::Api::Errors::InvalidAuth
      end
    end
  end
end
