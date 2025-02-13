# frozen_string_literal: true

RSpec.describe Spaceship::Slack2fa::VerificationCodeNotFound do
  it 'has a message' do
    expect(described_class.new.message).to match(/2FA code was sent but not found in Slack/)
  end
end
