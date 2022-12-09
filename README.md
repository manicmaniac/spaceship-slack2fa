# Spaceship::Slack2fa

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

- Bot token scope with `channels:history` permission
- The bot token is enabled on the relevant channel.

## Usage

For example, if you have a Fastfile like the following:

```ruby
lane :release do
  deliver
end
````

Wrap the `deliver` action in a block that is passed to `Spaceship::Slack2fa.enable`.

```ruby
lane :release do
  Spaceship::Slack2fa.enable(
    slack_api_token: "xoxb-xxxxxxxxx-xxxxxxxxx-xxxxxxxx",
    channel_id: "CXXXXXXXXXX",
    user_id: "UXXXXXXXXXX",
  ) do
    deliver
  end
end
````

I use `deliver` as an example, but any action that internally references `Spaceship::Client` can be used.

You can pass options to `Spaceship::Slack2fa.enable` as arguments.

- `slack_api_token`: Required. A token for the Slack app.
- `channel_id`: Required. The id of the channel where the message will be posted (you can get this from a part of the channel's URL).
- `user_id`: Required. The ID of the user posting the message (can be retrieved from their Slack profile).
- `retry_count`: Optional. The number of retries to try if a message is not found. The default is 3.
- `retry_interval`: Optional. The interval between retries in seconds. Default is 20.0.

## How it works

The `fastlane spaceship` invokes the `Spaceship::Client.ask_for_2fa_code` method to receive 2FA codes from standard input.

This gem temporarily rewrites the above method to use the Slack API's `conversations.history` to retrieve the message and return it.
The method rewriting only takes effect in the block passed to `Spaceship::Slack2fa.enable`.

## Known bugs

Basically, sending 2FA code to external service out of your device has security risk.
Use API key provided by App Store Connect instead, if possible.
