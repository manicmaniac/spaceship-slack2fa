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
    let(:response_json) { File.read(File.expand_path("../support/fixtures/conversations.history.json", __dir__)) }

    before do
      Spaceship::Client.define_method(:ask_for_2fa_code) { raise NotImplementedError }
      uri = double
      allow(uri).to receive(:open)
        .with("Authorization" => "Bearer SLACK_API_TOKEN")
        .once
        .and_return response_json
      allow(::URI).to receive(:parse).and_call_original
      allow(::URI).to receive(:parse)
        .with("https://slack.com/api/conversations.history?channel=CHANNEL_ID")
        .and_return uri
    end

    it "retrieves 2FA code from Slack messages" do
      expect(subject).to eq "123456"
    end

    context "when authentication failed" do
      let(:response_json) { File.read(File.expand_path("../support/fixtures/not_authed.json", __dir__)) }

      it "raises RuntimeError" do
        expect { subject }.to raise_error RuntimeError, starting_with("not_authed")
      end
    end
  end
end
