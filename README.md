# bolt-rb

> **Note:** This project is provided as-is with no active support. I'll add features when I need them and accept PRs if someone wants to contribute fixes. Use at your own risk.

A [bolt-js](https://slack.dev/bolt-js) inspired framework for building Slack bots in Ruby using Socket Mode.

## Installation

Add to your Gemfile:

```ruby
gem 'bolt_rb'
```

Then run:

```bash
bundle install
```

## Quick Start

```ruby
require 'bolt_rb'

BoltRb.configure do |config|
  config.bot_token = ENV.fetch('SLACK_BOT_TOKEN')
  config.app_token = ENV.fetch('SLACK_APP_TOKEN')
  config.handler_paths = ['./handlers']
end

app = BoltRb::App.new

# Graceful shutdown
%w[INT TERM].each do |signal|
  Signal.trap(signal) { app.request_stop }
end

app.start
```

## Configuration

| Option | Description |
|--------|-------------|
| `bot_token` | Your Slack bot token (`xoxb-...`) |
| `app_token` | Your Slack app-level token (`xapp-...`) for Socket Mode |
| `handler_paths` | Array of directories to load handlers from |

## Handlers

Handlers are auto-registered when loaded. Just drop them in your handler paths.

### Events

Listen to Slack events like messages, reactions, app mentions:

```ruby
class GreetingHandler < BoltRb::EventHandler
  listen_to :message, pattern: /hello/i

  def handle
    say "Hey there <@#{user}>!"
  end
end
```

```ruby
class MentionHandler < BoltRb::EventHandler
  listen_to :app_mention

  def handle
    say "You rang?"
  end
end
```

**Available methods:** `event`, `text`, `thread_ts`, `ts`, `user`, `channel`, `say`, `client`

### Slash Commands

Handle slash commands like `/deploy`:

```ruby
class DeployCommand < BoltRb::CommandHandler
  command '/deploy'

  def handle
    ack "Deploying #{command_text}..."
    # Do the work
    say "Deployed #{command_text} successfully!"
  end
end
```

**Available methods:** `command_name`, `command_text`, `trigger_id`, `user`, `channel`, `ack`, `say`, `respond`, `client`

### Actions

Handle button clicks, select menus, and other interactive components:

```ruby
class ApproveHandler < BoltRb::ActionHandler
  action 'approve_button'

  def handle
    ack
    say "Approved by <@#{user}>!"
  end
end
```

Supports regex matching:

```ruby
class DynamicButtonHandler < BoltRb::ActionHandler
  action /^approve_request_/

  def handle
    ack
    request_id = action_id.gsub('approve_request_', '')
    # Process the request
  end
end
```

**Available methods:** `action`, `action_id`, `action_value`, `block_id`, `trigger_id`, `user`, `channel`, `ack`, `say`, `respond`, `client`

### Shortcuts

Handle global shortcuts (lightning bolt menu) and message shortcuts:

```ruby
class CreateTicketHandler < BoltRb::ShortcutHandler
  shortcut 'create_ticket'

  def handle
    ack
    client.views_open(
      trigger_id: trigger_id,
      view: { type: 'modal', title: { type: 'plain_text', text: 'Create Ticket' }, ... }
    )
  end
end
```

**Available methods:** `callback_id`, `trigger_id`, `shortcut_type`, `message`, `message_text`, `user`, `channel`, `ack`, `client`

### View Submissions

Handle modal form submissions:

```ruby
class TicketSubmitHandler < BoltRb::ViewSubmissionHandler
  view 'create_ticket_modal'

  def handle
    title = values.dig('title_block', 'title_input', 'value')

    if title.nil? || title.empty?
      ack(response_action: 'errors', errors: { 'title_block' => 'Title is required' })
    else
      ack
      say "Created ticket: #{title}"
    end
  end
end
```

**Available methods:** `view`, `callback_id`, `private_metadata`, `values`, `view_hash`, `response_urls`, `user_id`, `ack`, `say`, `client`

## Handler Methods

All handlers have access to:

| Method | Description |
|--------|-------------|
| `say(message)` | Post a message to the channel |
| `ack(response)` | Acknowledge the event (required for commands, actions, shortcuts, views) |
| `respond(message)` | Send a response using the response_url |
| `client` | The `Slack::Web::Client` for API calls |
| `payload` | The raw Slack payload |
| `user` | The user ID who triggered the event |
| `channel` | The channel ID |

## Middleware

Add handler-specific middleware:

```ruby
class ProtectedHandler < BoltRb::CommandHandler
  command '/admin'
  use AdminOnlyMiddleware

  def handle
    # Only admins get here
  end
end
```

## Slack App Setup

1. Create a Slack app at [api.slack.com/apps](https://api.slack.com/apps)
2. Enable **Socket Mode** under Settings
3. Generate an **App-Level Token** with `connections:write` scope
4. Add a **Bot Token** with the scopes you need (e.g., `chat:write`, `commands`)
5. Install the app to your workspace

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT
