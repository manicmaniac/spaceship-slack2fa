# Spaceship::Slack2fa

[![Test](https://github.com/manicmaniac/spaceship-slack2fa/actions/workflows/test.yml/badge.svg)](https://github.com/manicmaniac/spaceship-slack2fa/actions/workflows/test.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/09d0f24cd63c448829ed/maintainability)](https://codeclimate.com/github/manicmaniac/spaceship-slack2fa/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/09d0f24cd63c448829ed/test_coverage)](https://codeclimate.com/github/manicmaniac/spaceship-slack2fa/test_coverage)

This is a gem to get the 6-digit code for AppStore Connect's 2 factor auth from posts to a specific Slack channel.
It can be used to automate deployment with actions like `fastlane deliver`.

## Installation

Add the following line to your Gemfile.

```ruby
gem "spaceship-slack2fa", git: "https://github.com/manicmaniac/spaceship-slack2fa.git"
```

Then run `bundle install`.


## Prerequisites

You have to create Slack app to read Slack messages beforehand.
Please create an app from https://api.slack.com/apps that meets the following requirements.

- Bot token scope with `channels.history` and `chat.write` permission
- The bot token is enabled on the relevant channel.

## Usage

For example, if you have a Fastfile like the following:

```ruby
lane :release do
  deliver
end
```

Just wrap the `deliver` action in a block that is passed to `Spaceship::Slack2fa.enable`.

Note that you may need to set `SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER` environment variable to tell Fastlane which phone number is preferred.

```ruby
require "spaceship/slack2fa"

lane :release do
  Spaceship::Slack2fa.enable(
    slack_api_token: "xoxb-000000000-000000000-XXXXXXXXXXXXXXXXXXXXXXXX",
    channel_id: "CXXXXXXXXXX",
    user_id: "UXXXXXXXXXX",
    referrer: "My App",
  ) do
    deliver
  end
end
```

I use `deliver` as an example, but any action that internally references `Spaceship::Client` can be used.

You can pass options to `Spaceship::Slack2fa.enable` as arguments.

- `slack_api_token`: Required. A bot token for your Slack app.
- `channel_id`: Required. The ID of the channel where the message will be posted.
- `user_id`: Required. The ID of the user posting the message.
- `referrer`: Required. A `mrkdwn` text to identify which service consumes 6-digit code, typically the name of your app.
- `allow_any_users`: Optional. If `true`, `spaceship-slack2fa` recognizes only messages from the bot user specified in `slack_api_token`, otherwise it treats all messages with 6-digits numbers as 2FA code. The default is `false`.
- `retry_count`: Optional. The number of retries to try if a message is not found. The default is `3`.
- `retry_interval`: Optional. The interval between retries in seconds. The default is `20`.

See [What is the simplest way to find a slack team ID and a channel ID?](https://stackoverflow.com/a/44883343/6918498) to know how to get channel ID and user ID.
## How it works

The `fastlane spaceship` invokes the `Spaceship::Client.ask_for_2fa_code` method to receive 2FA codes from standard input.

This gem temporarily rewrites the above method to use the Slack API's `conversations.history` to retrieve the message and return it.
The method rewriting only takes effect in the block passed to `Spaceship::Slack2fa.enable`.

## Known bugs

### Security

Basically, sending 2FA code to external service out of your device has security risk.
Use API key provided by App Store Connect instead, if possible.

### Concurrency

This program does not consider concurrency at all.
When you run multiple processes of this program and those watches the same Slack channel, some processes may retrieve wrong 2FA code.

## Testing

Run the following command to run test

```sh
bundle exec rake spec
```

You can use `bin/login-to-appstore-connect` to do end-to-end testing.
This script does nothing but login to AppStore Connect.

:warning: Note that your account will be locked out if you request Apple to send 2FA code many times without establishing a session.

```sh
bin/login-to-appstore-connect \
  --user 'developer@example.com' \
  --password 'PASSWORD' \
  --phone_number '+81 80-XXXX-XXXX' \
  --slack_api_token 'xoxb-XXXXXXXX' \
  --slack_channel_id CXXXXXXXX \
  --slack_user_id UXXXXXXXX
```

Or you can pass some of the options though environment variables.

```sh
export FASTLANE_USER=developer@example.com
export FASTLANE_PASSWORD=PASSWORD
export SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER='+81 80-XXXX-XXXX'

bin/login-to-appstore-connect -t 'xoxb-XXXXXXXX' -c CXXXXXXXX -s UXXXXXXXX
```

After the script successfully establish login session, you can see `~/.fastlane/spaceship/*/cookie`, which serializes a cookie of AppStore Connect.

## Release

This library is not intended to be published on rubygems.org.
So the release flow is simple as described below.

### 1. Create a pull request to bump version

```sh
export VERSION='x.x.x'
git checkout -b "release/$VERSION"
ruby -pi -e 'sub(/[0-9.]+/, ENV["VERSION"]) if /VERSION/' lib/spaceship/slack2fa/version.rb
bundle install
git commit -am "Bump version to $VERSION"
gh pr create -fa@me
gh pr merge -dm --auto
```

### 2. Publish release

After the pull request is merged, run the following commands.

```sh
export VERSION='x.x.x'
git tag -am "$VERSION" "$VERSION"
git push origin "$VERSION"
gh release create -t "$VERSION" --generate-notes "$VERSION"
```
