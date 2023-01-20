# frozen_string_literal: true

RSpec.describe Spaceship::Slack2fa do
  it 'has a version number' do
    expect(Spaceship::Slack2fa::VERSION).not_to be_nil
  end

  describe '.enable' do
    subject :ask_for_2fa_code do
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
        retry_interval: 0.01
      }
    end
    let(:retry_count) { 0 }
    let(:slack) { instance_double(Slack::Web::Client) }
    let(:log) { StringIO.new }

    # jq '.messages | map(.ts | tonumber) | min | floor' < spec/support/fixtures/conversations.history.json
    oldest = 1_512_085_950

    before do
      Spaceship::Client.define_method(:ask_for_2fa_code) { raise NotImplementedError }
      allow(Slack::Web::Client).to receive(:new)
        .with(token: 'SLACK_API_TOKEN')
        .and_return slack
      logger = Logger.new(log)
      allow(Logger).to receive(:new)
        .with($stderr)
        .and_return logger
      allow(Time).to receive(:now).and_return Time.at(oldest)
    end

    context 'when authenticated' do
      before do
        json_path = File.expand_path('../support/fixtures/conversations.history.json', __dir__)
        json = JSON.parse(File.read(json_path))
        allow(slack).to receive(:conversations_history)
          .with(channel: 'CHANNEL_ID', oldest: oldest)
          .and_return Slack::Messages::Message.new(json)
        allow(slack).to receive(:chat_postMessage)
      end

      it 'retrieves 2FA code from Slack messages' do
        expect(ask_for_2fa_code).to eq '123456'
      end

      it 'posts a comment on the thread' do
        ask_for_2fa_code
        expect(slack).to have_received(:chat_postMessage)
          .with(channel: 'CHANNEL_ID',
                text: a_string_including('REFERRER'),
                thread_ts: '1512104434.000490')
      end

      it 'removes temporary method' do
        ask_for_2fa_code
        expect(client).not_to respond_to :original_ask_for_2fa_code
      end
    end

    context 'when the first API call returns no code and the second returns a code' do
      let(:retry_count) { 1 }

      before do
        json_paths = [
          '../support/fixtures/conversations.history.empty.json',
          '../support/fixtures/conversations.history.json'
        ]
        messages = json_paths
                   .map { |path| File.read(File.expand_path(path, __dir__)) }
                   .map { |text| JSON.parse(text) }
                   .map { |json| Slack::Messages::Message.new(json) }
        allow(slack).to receive(:conversations_history)
          .with(channel: 'CHANNEL_ID', oldest: oldest)
          .and_return(*messages)
        allow(slack).to receive(:chat_postMessage)
      end

      it 'retrieves 2FA code from Slack messages' do
        expect(ask_for_2fa_code).to eq '123456'
      end

      it 'calls API twice' do
        ask_for_2fa_code
        expect(slack).to have_received(:conversations_history).with(channel: 'CHANNEL_ID', oldest: oldest).twice
      end
    end

    context 'when channel.history is missing in scope' do
      before do
        allow(slack).to receive(:conversations_history)
          .and_raise Slack::Web::Api::Errors::MissingScope.new('missing scope')
      end

      it 'raises an error' do
        expect { ask_for_2fa_code }.to raise_error Slack::Web::Api::Errors::MissingScope
      end
    end

    context 'when chat.write is missing in scope' do
      before do
        json_path = File.expand_path('../support/fixtures/conversations.history.json', __dir__)
        json = JSON.parse(File.read(json_path))
        allow(slack).to receive(:conversations_history)
          .with(channel: 'CHANNEL_ID', oldest: oldest)
          .and_return Slack::Messages::Message.new(json)
        allow(slack).to receive(:chat_postMessage)
          .and_raise Slack::Web::Api::Errors::MissingScope.new('missing scope')
      end

      it 'retrieves 2FA code from Slack messages' do
        expect(ask_for_2fa_code).to eq '123456'
      end

      it 'logs an error' do
        ask_for_2fa_code
        expect(log.string).to include 'missing scope'
      end
    end

    context 'when authentication failed' do
      before do
        allow(slack).to receive(:conversations_history)
          .and_raise Slack::Web::Api::Errors::InvalidAuth.new('invalid_auth')
      end

      it 'raises RuntimeError' do
        expect { ask_for_2fa_code }.to raise_error Slack::Web::Api::Errors::InvalidAuth
      end
    end
  end
end
