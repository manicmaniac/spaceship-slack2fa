module Spaceship
  module Slack2fa
    # An exception raised when 2FA code is not found after retries.
    # Do not retry after this error, otherwise your account will be locked.
    # See https://github.com/manicmaniac/spaceship-slack2fa/issues/59 for the detail.
    class VerificationCodeNotFound < StandardError
      def message
        '2FA code was sent but not found in Slack. Please make sure your code is successfully sent.'
      end
    end
  end
end