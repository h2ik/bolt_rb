# bolt-rb Design Document

A lightweight Ruby framework for building Slack bots using Socket Mode, inspired by bolt-js.

## Overview

**Goal:** Provide a bolt-js style DSL for handling Slack events in Ruby, built on top of `slack-ruby-client`.

**Target use case:** Single-workspace internal bots that run as a separate process alongside a Rails app, with access to Rails models and services.

## Requirements

- Handle all four Slack interaction types: Events, Slash Commands, Interactive Components, Shortcuts
- Class-based handlers for testability
- Middleware system for cross-cutting concerns
- First-class testing support with payload factories
- Runs as separate process, boots Rails environment (like Sidekiq)

## Dependencies

- `slack-ruby-client` - WebSocket connection (Socket Mode) and Slack Web API
- `concurrent-ruby` - Thread-safe handler registry (optional)

## Architecture

### Directory Structure

```
lib/
├── bolt_rb.rb                       # Main entry, configuration
├── bolt_rb/
│   ├── app.rb                       # Main application class
│   ├── configuration.rb             # Config object (tokens, logger, etc.)
│   ├── router.rb                    # Routes events to handlers
│   ├── context.rb                   # Request context passed to handlers
│   │
│   ├── handlers/
│   │   ├── base.rb                  # Base class all handlers inherit
│   │   ├── event_handler.rb         # For Slack events
│   │   ├── command_handler.rb       # For slash commands
│   │   ├── action_handler.rb        # For interactive components
│   │   └── shortcut_handler.rb      # For shortcuts
│   │
│   ├── middleware/
│   │   ├── chain.rb                 # Middleware executor
│   │   ├── base.rb                  # Base middleware class
│   │   └── logging.rb               # Default logging middleware
│   │
│   ├── testing/
│   │   ├── rspec.rb                 # RSpec integration
│   │   └── payload_factory.rb       # Build fake Slack payloads
│   │
│   └── railtie.rb                   # Rails integration (optional)
```

### Handler Base Classes

All handlers inherit from `BoltRb::Handlers::Base` which provides:

- Access to `context`, `payload`, `client`
- Convenience methods: `say`, `ack`, `respond`
- Helper methods: `user`, `channel`

#### Event Handler

```ruby
class GreetingHandler < BoltRb::EventHandler
  listen_to :message, pattern: /hello/i

  def handle
    say "Hey there <@#{user}>!"
  end
end
```

#### Command Handler

```ruby
class DeployCommand < BoltRb::CommandHandler
  command '/deploy'

  def handle
    ack "Deploying #{params[:text]}..."
    result = DeployService.call(params[:text], triggered_by: user)
    say result.success? ? "Deploy complete" : "Deploy failed: #{result.error}"
  end
end
```

#### Action Handler

```ruby
class ApproveAction < BoltRb::ActionHandler
  action 'approve_request'

  def handle
    ack
    request = Request.find(action_value)
    request.approve!(by: user)
    respond blocks: approved_message_blocks(request)
  end
end
```

#### Shortcut Handler

```ruby
class CreateTicketShortcut < BoltRb::ShortcutHandler
  shortcut 'create_ticket'

  def handle
    ack
    client.views_open(trigger_id: trigger_id, view: ticket_modal)
  end
end
```

### Router

The router auto-registers handler classes and matches incoming events:

```ruby
module BoltRb
  class Router
    def initialize
      @handlers = { event: [], command: [], action: [], shortcut: [] }
    end

    def register(handler_class)
      config = handler_class.matcher_config
      @handlers[config[:type]] << handler_class
    end

    def route(event_type, payload)
      @handlers[event_type].select { |h| matches?(h, payload) }
    end
  end
end
```

Handlers are auto-registered when their class is defined via `inherited` hook.

### Middleware

Middleware follows a chain-of-responsibility pattern:

```ruby
class AdminOnlyMiddleware < BoltRb::Middleware::Base
  ADMIN_IDS = %w[U123ABC U456DEF].freeze

  def call(context)
    unless ADMIN_IDS.include?(context.user_id)
      context.respond "This command is for admins only."
      return
    end
    yield
  end
end
```

Apply middleware globally or per-handler:

```ruby
# Global
BoltRb.configure do |config|
  config.use LoggingMiddleware
end

# Per-handler
class DangerousCommand < BoltRb::CommandHandler
  command '/danger'
  use AdminOnlyMiddleware

  def handle
    # ...
  end
end
```

**Default middleware:** `LoggingMiddleware` is included by default.

### Context

The `Context` object wraps the event and provides access to:

- `payload` - Raw Slack event payload
- `client` - Slack Web API client
- `ack` - Acknowledgment function
- `say(text_or_options)` - Post to originating channel
- `respond(text_or_options)` - Use response_url for ephemeral messages

### Testing

#### Payload Factory

```ruby
module BoltRb
  module Testing
    class PayloadFactory
      def self.message(text:, user: 'U123TEST', channel: 'C456TEST')
        # Returns properly structured Slack message event
      end

      def self.command(command:, text: '', user: 'U123TEST')
        # Returns properly structured slash command payload
      end

      def self.action(action_id:, value: nil, user: 'U123TEST')
        # Returns properly structured block_actions payload
      end

      def self.shortcut(callback_id:, user: 'U123TEST')
        # Returns properly structured shortcut payload
      end
    end
  end
end
```

#### RSpec Helpers

```ruby
RSpec.describe DeployCommand, type: :slack_handler do
  describe '#handle' do
    let(:context) { build_context(payload.command(command: '/deploy', text: 'production')) }

    it 'acknowledges immediately' do
      allow(DeployService).to receive(:call).and_return(double(success?: true))
      described_class.new(context).handle
      expect(context).to be_acked
    end

    it 'calls DeployService with the environment' do
      expect(DeployService).to receive(:call).with('production', triggered_by: anything)
      described_class.new(context).handle
    end
  end
end
```

### Rails Integration

#### Configuration

```ruby
# config/initializers/bolt_rb.rb
BoltRb.configure do |config|
  config.bot_token = ENV.fetch('SLACK_BOT_TOKEN')
  config.app_token = ENV.fetch('SLACK_APP_TOKEN')
  config.handler_paths = [Rails.root.join('app/slack_handlers')]
  config.logger = Rails.logger

  config.error_handler = ->(error, event) do
    Sentry.capture_exception(error, extra: { slack_event: event })
  end
end
```

#### Binstub

```ruby
#!/usr/bin/env ruby
# bin/slack_bot
require_relative '../config/environment'

app = BoltRb::App.new

%w[INT TERM].each do |signal|
  Signal.trap(signal) do
    app.stop
    exit 0
  end
end

app.start
```

#### Procfile

```
web: bundle exec puma -C config/puma.rb
slack: bundle exec bin/slack_bot
worker: bundle exec sidekiq
```

## Event Flow

```
Slack Socket Mode Event
    ↓
slack-ruby-client receives WebSocket message
    ↓
BoltRb::App#process_event
    ↓
Router finds matching handlers
    ↓
Build Context object
    ↓
Run global middleware chain
    ↓
For each matching handler:
    Run handler-specific middleware
    Execute #handle method
    ↓
Handle errors via error_handler
```

## File Locations (Rails App)

```
app/
└── slack_handlers/
    ├── greeting_handler.rb
    ├── deploy_command.rb
    ├── approve_action.rb
    └── create_ticket_shortcut.rb

config/
└── initializers/
    └── bolt_rb.rb

bin/
└── slack_bot
```

## Implementation Notes

- Handlers discovered via `inherited` hook when class loads
- Socket Mode preferred over HTTP (no public endpoint needed)
- All events must be acknowledged within 3 seconds
- Multiple handlers can match the same event (all will execute)
- Handler execution errors are logged and passed to error_handler, but don't crash the process
