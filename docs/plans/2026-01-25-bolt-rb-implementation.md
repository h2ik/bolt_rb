# bolt-rb Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a lightweight Ruby gem providing bolt-js style DSL for Slack bots using Socket Mode.

**Architecture:** Handler base classes with class-level DSL for matching events, router for auto-registration and dispatch, middleware chain for cross-cutting concerns, and testing utilities for isolated handler specs.

**Tech Stack:** Ruby 3.x, slack-ruby-client gem, RSpec for testing, Bundler for gem packaging

---

### Task 1: Gem Skeleton

**Files:**
- Create: `bolt_rb.gemspec`
- Create: `Gemfile`
- Create: `lib/bolt_rb.rb`
- Create: `lib/bolt_rb/version.rb`
- Create: `.rspec`
- Create: `spec/spec_helper.rb`
- Create: `.gitignore`
- Create: `README.md`

**Step 1: Create .gitignore**

```gitignore
/.bundle/
/.yardoc
/_yardoc/
/coverage/
/doc/
/pkg/
/spec/reports/
/tmp/
*.gem
*.rbc
.byebug_history
Gemfile.lock
```

**Step 2: Create version file**

```ruby
# lib/bolt_rb/version.rb
module BoltRb
  VERSION = '0.1.0'
end
```

**Step 3: Create main entry point**

```ruby
# lib/bolt_rb.rb
require_relative 'bolt_rb/version'

module BoltRb
  class Error < StandardError; end
end
```

**Step 4: Create gemspec**

```ruby
# bolt_rb.gemspec
require_relative 'lib/bolt_rb/version'

Gem::Specification.new do |spec|
  spec.name          = 'bolt_rb'
  spec.version       = BoltRb::VERSION
  spec.authors       = ['Your Name']
  spec.email         = ['your@email.com']

  spec.summary       = 'A bolt-js inspired framework for building Slack bots in Ruby'
  spec.description   = 'Provides a clean DSL for handling Slack events, commands, actions, and shortcuts using Socket Mode'
  spec.homepage      = 'https://github.com/slackapi/bolt-rb'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files = Dir.glob('{lib}/**/*') + %w[README.md LICENSE.txt]
  spec.require_paths = ['lib']

  spec.add_dependency 'slack-ruby-client', '~> 2.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
end
```

**Step 5: Create Gemfile**

```ruby
# Gemfile
source 'https://rubygems.org'

gemspec
```

**Step 6: Create RSpec config**

```
# .rspec
--require spec_helper
--format documentation
--color
```

```ruby
# spec/spec_helper.rb
require 'bundler/setup'
require 'bolt_rb'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
```

**Step 7: Create minimal README**

```markdown
# bolt-rb

A bolt-js inspired framework for building Slack bots in Ruby using Socket Mode.

## Installation

Add to your Gemfile:

\`\`\`ruby
gem 'bolt_rb'
\`\`\`

## Usage

Coming soon.

## Development

\`\`\`bash
bundle install
bundle exec rspec
\`\`\`

## License

MIT
```

**Step 8: Install dependencies and verify**

Run: `cd /Users/jon.whitcraft/Projects/slackapi/bolt-rb && bundle install`
Expected: Dependencies installed successfully

Run: `bundle exec rspec`
Expected: 0 examples, 0 failures

**Step 9: Commit**

```bash
git add -A
git commit -m "chore: initialize gem skeleton with RSpec"
```

---

### Task 2: Configuration Module

**Files:**
- Create: `lib/bolt_rb/configuration.rb`
- Create: `spec/bolt_rb/configuration_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/configuration_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default handler_paths' do
      expect(config.handler_paths).to eq(['app/slack_handlers'])
    end

    it 'sets default logger' do
      expect(config.logger).to be_a(Logger)
    end

    it 'initializes empty middleware array with logging' do
      expect(config.middleware).to eq([BoltRb::Middleware::Logging])
    end
  end

  describe 'accessors' do
    it 'allows setting bot_token' do
      config.bot_token = 'xoxb-test'
      expect(config.bot_token).to eq('xoxb-test')
    end

    it 'allows setting app_token' do
      config.app_token = 'xapp-test'
      expect(config.app_token).to eq('xapp-test')
    end

    it 'allows setting error_handler' do
      handler = ->(e, event) { puts e }
      config.error_handler = handler
      expect(config.error_handler).to eq(handler)
    end
  end

  describe '#use' do
    it 'adds middleware to the stack' do
      middleware_class = Class.new
      config.use(middleware_class)
      expect(config.middleware).to include(middleware_class)
    end
  end
end

RSpec.describe BoltRb do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(BoltRb.configuration).to be_a(BoltRb::Configuration)
    end

    it 'memoizes the configuration' do
      expect(BoltRb.configuration).to be(BoltRb.configuration)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      BoltRb.configure do |config|
        expect(config).to be(BoltRb.configuration)
      end
    end
  end

  describe '.reset_configuration!' do
    it 'resets to a new configuration' do
      old_config = BoltRb.configuration
      BoltRb.reset_configuration!
      expect(BoltRb.configuration).not_to be(old_config)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/configuration_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Create stub middleware module for default**

```ruby
# lib/bolt_rb/middleware/logging.rb
module BoltRb
  module Middleware
    class Logging
    end
  end
end
```

**Step 4: Write implementation**

```ruby
# lib/bolt_rb/configuration.rb
require 'logger'

module BoltRb
  class Configuration
    attr_accessor :bot_token, :app_token, :signing_secret,
                  :handler_paths, :logger, :error_handler

    attr_reader :middleware

    def initialize
      @handler_paths = ['app/slack_handlers']
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @middleware = [BoltRb::Middleware::Logging]
    end

    def use(middleware_class)
      @middleware << middleware_class
    end
  end
end
```

**Step 5: Update main entry point**

```ruby
# lib/bolt_rb.rb
require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'

module BoltRb
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def logger
      configuration.logger
    end
  end
end
```

**Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/configuration_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Configuration module with defaults"
```

---

### Task 3: Context Class

**Files:**
- Create: `lib/bolt_rb/context.rb`
- Create: `spec/bolt_rb/context_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/context_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Context do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { instance_double(Proc) }
  let(:payload) do
    {
      'event' => {
        'type' => 'message',
        'text' => 'hello world',
        'user' => 'U123ABC',
        'channel' => 'C456DEF',
        'ts' => '1234567890.123456'
      }
    }
  end

  subject(:context) do
    described_class.new(payload: payload, client: client, ack: ack_fn)
  end

  describe '#initialize' do
    it 'stores the payload' do
      expect(context.payload).to eq(payload)
    end

    it 'stores the client' do
      expect(context.client).to eq(client)
    end
  end

  describe '#event' do
    it 'returns the event from payload' do
      expect(context.event).to eq(payload['event'])
    end
  end

  describe '#user' do
    it 'extracts user from event' do
      expect(context.user).to eq('U123ABC')
    end

    context 'when user is nested object' do
      let(:payload) { { 'user' => { 'id' => 'U789XYZ' } } }

      it 'extracts user id' do
        expect(context.user).to eq('U789XYZ')
      end
    end
  end

  describe '#channel' do
    it 'extracts channel from event' do
      expect(context.channel).to eq('C456DEF')
    end

    context 'when channel is nested object' do
      let(:payload) { { 'channel' => { 'id' => 'C999ZZZ' } } }

      it 'extracts channel id' do
        expect(context.channel).to eq('C999ZZZ')
      end
    end
  end

  describe '#text' do
    it 'extracts text from event' do
      expect(context.text).to eq('hello world')
    end
  end

  describe '#ack' do
    it 'calls the ack function with no args' do
      allow(ack_fn).to receive(:call)
      context.ack
      expect(ack_fn).to have_received(:call).with(nil)
    end

    it 'calls the ack function with response' do
      allow(ack_fn).to receive(:call)
      context.ack('Processing...')
      expect(ack_fn).to have_received(:call).with('Processing...')
    end

    it 'marks context as acked' do
      allow(ack_fn).to receive(:call)
      context.ack
      expect(context).to be_acked
    end
  end

  describe '#say' do
    before do
      allow(client).to receive(:chat_postMessage).and_return({ 'ok' => true })
    end

    it 'posts message to channel' do
      context.say('Hello!')
      expect(client).to have_received(:chat_postMessage).with(
        hash_including(channel: 'C456DEF', text: 'Hello!')
      )
    end

    it 'accepts options hash' do
      context.say(text: 'Hello!', thread_ts: '123.456')
      expect(client).to have_received(:chat_postMessage).with(
        hash_including(channel: 'C456DEF', text: 'Hello!', thread_ts: '123.456')
      )
    end
  end

  describe '#respond' do
    let(:payload) do
      { 'response_url' => 'https://hooks.slack.com/commands/xxx' }
    end

    before do
      stub_request(:post, 'https://hooks.slack.com/commands/xxx')
        .to_return(status: 200, body: '{"ok":true}')
    end

    it 'posts to response_url' do
      context.respond('Ephemeral message')
      expect(WebMock).to have_requested(:post, 'https://hooks.slack.com/commands/xxx')
        .with(body: hash_including('text' => 'Ephemeral message'))
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/context_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Add webmock to gemspec for testing**

Add to `bolt_rb.gemspec` in development dependencies:
```ruby
spec.add_development_dependency 'webmock', '~> 3.18'
```

Update `spec/spec_helper.rb`:
```ruby
require 'bundler/setup'
require 'bolt_rb'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # ... existing config
end
```

Run: `bundle install`

**Step 4: Write implementation**

```ruby
# lib/bolt_rb/context.rb
require 'net/http'
require 'json'

module BoltRb
  class Context
    attr_reader :payload, :client

    def initialize(payload:, client:, ack:)
      @payload = payload
      @client = client
      @ack_fn = ack
      @acked = false
    end

    def event
      payload['event']
    end

    def user
      extract_id(payload.dig('event', 'user') || payload['user'] || payload.dig('user', 'id'))
    end

    def channel
      extract_id(payload.dig('event', 'channel') || payload['channel'] || payload.dig('channel', 'id'))
    end

    def text
      event&.dig('text')
    end

    def ack(response = nil)
      @ack_fn.call(response)
      @acked = true
    end

    def acked?
      @acked
    end

    def say(message)
      options = message.is_a?(Hash) ? message : { text: message }
      client.chat_postMessage(options.merge(channel: channel))
    end

    def respond(message)
      response_url = payload['response_url']
      return unless response_url

      options = message.is_a?(Hash) ? message : { text: message }
      uri = URI(response_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request.body = options.to_json
      http.request(request)
    end

    private

    def extract_id(value)
      return nil if value.nil?
      value.is_a?(Hash) ? value['id'] : value
    end
  end
end
```

**Step 5: Update main entry point**

```ruby
# lib/bolt_rb.rb
require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'
require_relative 'bolt_rb/context'

# ... rest unchanged
```

**Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/context_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Context class with say, ack, respond"
```

---

### Task 4: Base Handler Class

**Files:**
- Create: `lib/bolt_rb/handlers/base.rb`
- Create: `spec/bolt_rb/handlers/base_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/handlers/base_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Handlers::Base do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:payload) do
    {
      'event' => {
        'type' => 'message',
        'text' => 'hello',
        'user' => 'U123',
        'channel' => 'C456'
      }
    }
  end
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }

  describe 'class methods' do
    describe '.matcher_config' do
      it 'returns nil by default' do
        expect(described_class.matcher_config).to be_nil
      end
    end

    describe '.middleware_stack' do
      it 'returns empty array by default' do
        expect(described_class.middleware_stack).to eq([])
      end
    end

    describe '.use' do
      let(:handler_class) do
        Class.new(described_class) do
          use Class.new
        end
      end

      it 'adds middleware to the stack' do
        expect(handler_class.middleware_stack.length).to eq(1)
      end
    end

    describe '.matches?' do
      it 'returns false by default' do
        expect(described_class.matches?(payload)).to be false
      end
    end
  end

  describe 'instance methods' do
    subject(:handler) { described_class.new(context) }

    describe '#context' do
      it 'returns the context' do
        expect(handler.context).to eq(context)
      end
    end

    describe '#payload' do
      it 'returns payload from context' do
        expect(handler.payload).to eq(payload)
      end
    end

    describe '#client' do
      it 'returns client from context' do
        expect(handler.client).to eq(client)
      end
    end

    describe '#user' do
      it 'delegates to context' do
        expect(handler.user).to eq('U123')
      end
    end

    describe '#channel' do
      it 'delegates to context' do
        expect(handler.channel).to eq('C456')
      end
    end

    describe '#say' do
      it 'delegates to context' do
        allow(client).to receive(:chat_postMessage)
        handler.say('test')
        expect(client).to have_received(:chat_postMessage)
      end
    end

    describe '#ack' do
      it 'delegates to context' do
        handler.ack
        expect(context).to be_acked
      end
    end

    describe '#call' do
      let(:handler_class) do
        Class.new(described_class) do
          def handle
            @handled = true
          end

          attr_reader :handled
        end
      end

      it 'calls handle method' do
        instance = handler_class.new(context)
        instance.call
        expect(instance.handled).to be true
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/handlers/base_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/handlers/base.rb
module BoltRb
  module Handlers
    class Base
      class << self
        attr_reader :matcher_config

        def middleware_stack
          @middleware_stack ||= []
        end

        def use(middleware_class)
          middleware_stack << middleware_class
        end

        def matches?(_payload)
          false
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@middleware_stack, [])
        end
      end

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def payload
        context.payload
      end

      def client
        context.client
      end

      def user
        context.user
      end

      def channel
        context.channel
      end

      def say(message)
        context.say(message)
      end

      def ack(response = nil)
        context.ack(response)
      end

      def respond(message)
        context.respond(message)
      end

      def call
        run_middleware { handle }
      end

      def handle
        raise NotImplementedError, 'Subclasses must implement #handle'
      end

      private

      def run_middleware(&block)
        chain = self.class.middleware_stack.dup
        run_next = proc do
          if chain.empty?
            block.call
          else
            middleware = chain.shift.new
            middleware.call(context) { run_next.call }
          end
        end
        run_next.call
      end
    end
  end
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb
require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'
require_relative 'bolt_rb/context'
require_relative 'bolt_rb/handlers/base'

# ... rest unchanged
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/handlers/base_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Handlers::Base class with middleware support"
```

---

### Task 5: Event Handler

**Files:**
- Create: `lib/bolt_rb/handlers/event_handler.rb`
- Create: `spec/bolt_rb/handlers/event_handler_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/handlers/event_handler_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::EventHandler do
  describe '.listen_to' do
    let(:handler_class) do
      Class.new(described_class) do
        listen_to :message
      end
    end

    it 'sets matcher_config type to :event' do
      expect(handler_class.matcher_config[:type]).to eq(:event)
    end

    it 'sets the event_type' do
      expect(handler_class.matcher_config[:event_type]).to eq(:message)
    end

    context 'with pattern' do
      let(:handler_class) do
        Class.new(described_class) do
          listen_to :message, pattern: /hello/i
        end
      end

      it 'stores the pattern' do
        expect(handler_class.matcher_config[:pattern]).to eq(/hello/i)
      end
    end
  end

  describe '.matches?' do
    context 'event type only' do
      let(:handler_class) do
        Class.new(described_class) do
          listen_to :message
        end
      end

      it 'matches when event type matches' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'anything' } }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match wrong event type' do
        payload = { 'event' => { 'type' => 'app_mention' } }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'with pattern' do
      let(:handler_class) do
        Class.new(described_class) do
          listen_to :message, pattern: /hello/i
        end
      end

      it 'matches when pattern matches text' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'Hello world' } }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match when pattern does not match' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'goodbye' } }
        expect(handler_class.matches?(payload)).to be false
      end

      it 'does not match when text is nil' do
        payload = { 'event' => { 'type' => 'message' } }
        expect(handler_class.matches?(payload)).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { ->(_) {} }
    let(:payload) do
      {
        'event' => {
          'type' => 'message',
          'text' => 'hello there',
          'user' => 'U123',
          'channel' => 'C456',
          'ts' => '1234.5678'
        }
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler_class) do
      Class.new(described_class) do
        listen_to :message

        def handle
          # no-op for test
        end
      end
    end

    subject(:handler) { handler_class.new(context) }

    describe '#event' do
      it 'returns the event object' do
        expect(handler.event).to eq(payload['event'])
      end
    end

    describe '#text' do
      it 'returns the event text' do
        expect(handler.text).to eq('hello there')
      end
    end

    describe '#thread_ts' do
      it 'returns nil when not in thread' do
        expect(handler.thread_ts).to be_nil
      end

      context 'when in a thread' do
        let(:payload) do
          {
            'event' => {
              'type' => 'message',
              'text' => 'reply',
              'thread_ts' => '1234.5678'
            }
          }
        end

        it 'returns the thread_ts' do
          expect(handler.thread_ts).to eq('1234.5678')
        end
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/handlers/event_handler_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/handlers/event_handler.rb
module BoltRb
  module Handlers
    class EventHandler < Base
      class << self
        def listen_to(event_type, pattern: nil)
          @matcher_config = {
            type: :event,
            event_type: event_type,
            pattern: pattern
          }
        end

        def matches?(payload)
          return false unless matcher_config

          event = payload['event']
          return false unless event
          return false unless event['type'].to_s == matcher_config[:event_type].to_s

          if matcher_config[:pattern]
            return false if event['text'].nil?
            return matcher_config[:pattern].match?(event['text'])
          end

          true
        end
      end

      def event
        payload['event']
      end

      def text
        event&.dig('text')
      end

      def thread_ts
        event&.dig('thread_ts')
      end

      def ts
        event&.dig('ts')
      end
    end
  end

  # Top-level alias for convenience
  EventHandler = Handlers::EventHandler
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require)
require_relative 'bolt_rb/handlers/event_handler'
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/handlers/event_handler_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add EventHandler with listen_to DSL"
```

---

### Task 6: Command Handler

**Files:**
- Create: `lib/bolt_rb/handlers/command_handler.rb`
- Create: `spec/bolt_rb/handlers/command_handler_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/handlers/command_handler_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::CommandHandler do
  describe '.command' do
    let(:handler_class) do
      Class.new(described_class) do
        command '/deploy'
      end
    end

    it 'sets matcher_config type to :command' do
      expect(handler_class.matcher_config[:type]).to eq(:command)
    end

    it 'sets the command name' do
      expect(handler_class.matcher_config[:command]).to eq('/deploy')
    end
  end

  describe '.matches?' do
    let(:handler_class) do
      Class.new(described_class) do
        command '/deploy'
      end
    end

    it 'matches when command matches' do
      payload = { 'command' => '/deploy', 'text' => 'production' }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'does not match wrong command' do
      payload = { 'command' => '/rollback', 'text' => 'production' }
      expect(handler_class.matches?(payload)).to be false
    end
  end

  describe 'instance methods' do
    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { ->(_) {} }
    let(:payload) do
      {
        'command' => '/deploy',
        'text' => 'production --force',
        'user_id' => 'U123',
        'channel_id' => 'C456',
        'response_url' => 'https://hooks.slack.com/commands/xxx',
        'trigger_id' => 'trigger123'
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler_class) do
      Class.new(described_class) do
        command '/deploy'

        def handle
          # no-op
        end
      end
    end

    subject(:handler) { handler_class.new(context) }

    describe '#command_name' do
      it 'returns the command' do
        expect(handler.command_name).to eq('/deploy')
      end
    end

    describe '#command_text' do
      it 'returns the text after command' do
        expect(handler.command_text).to eq('production --force')
      end
    end

    describe '#params' do
      it 'returns hash with text' do
        expect(handler.params[:text]).to eq('production --force')
      end
    end

    describe '#trigger_id' do
      it 'returns the trigger_id for modals' do
        expect(handler.trigger_id).to eq('trigger123')
      end
    end

    describe '#user' do
      it 'extracts user_id from command payload' do
        expect(handler.user).to eq('U123')
      end
    end

    describe '#channel' do
      it 'extracts channel_id from command payload' do
        expect(handler.channel).to eq('C456')
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/handlers/command_handler_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/handlers/command_handler.rb
module BoltRb
  module Handlers
    class CommandHandler < Base
      class << self
        def command(command_name)
          @matcher_config = {
            type: :command,
            command: command_name
          }
        end

        def matches?(payload)
          return false unless matcher_config
          payload['command'] == matcher_config[:command]
        end
      end

      def command_name
        payload['command']
      end

      def command_text
        payload['text']
      end

      def params
        { text: command_text }
      end

      def trigger_id
        payload['trigger_id']
      end

      def user
        payload['user_id'] || super
      end

      def channel
        payload['channel_id'] || super
      end
    end
  end

  CommandHandler = Handlers::CommandHandler
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require)
require_relative 'bolt_rb/handlers/command_handler'
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/handlers/command_handler_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add CommandHandler with command DSL"
```

---

### Task 7: Action Handler

**Files:**
- Create: `lib/bolt_rb/handlers/action_handler.rb`
- Create: `spec/bolt_rb/handlers/action_handler_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/handlers/action_handler_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::ActionHandler do
  describe '.action' do
    let(:handler_class) do
      Class.new(described_class) do
        action 'approve_button'
      end
    end

    it 'sets matcher_config type to :action' do
      expect(handler_class.matcher_config[:type]).to eq(:action)
    end

    it 'sets the action_id' do
      expect(handler_class.matcher_config[:action_id]).to eq('approve_button')
    end

    context 'with block_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve_button', block_id: 'approval_block'
        end
      end

      it 'stores the block_id' do
        expect(handler_class.matcher_config[:block_id]).to eq('approval_block')
      end
    end

    context 'with regex' do
      let(:handler_class) do
        Class.new(described_class) do
          action /^approve_/
        end
      end

      it 'stores regex pattern' do
        expect(handler_class.matcher_config[:action_id]).to eq(/^approve_/)
      end
    end
  end

  describe '.matches?' do
    context 'string action_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve_button'
        end
      end

      it 'matches when action_id matches' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve_button', 'value' => '123' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match wrong action_id' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'reject_button' }]
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'regex action_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action /^approve_/
        end
      end

      it 'matches when pattern matches' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve_request_123' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end
    end

    context 'with block_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve', block_id: 'approvals'
        end
      end

      it 'matches when both action_id and block_id match' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve', 'block_id' => 'approvals' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match when block_id differs' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve', 'block_id' => 'other' }]
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { ->(_) {} }
    let(:payload) do
      {
        'type' => 'block_actions',
        'user' => { 'id' => 'U123' },
        'channel' => { 'id' => 'C456' },
        'actions' => [{
          'action_id' => 'approve_button',
          'block_id' => 'approval_block',
          'value' => 'request_789'
        }],
        'trigger_id' => 'trigger123',
        'response_url' => 'https://hooks.slack.com/actions/xxx'
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler_class) do
      Class.new(described_class) do
        action 'approve_button'

        def handle
          # no-op
        end
      end
    end

    subject(:handler) { handler_class.new(context) }

    describe '#action' do
      it 'returns the first action' do
        expect(handler.action).to eq(payload['actions'].first)
      end
    end

    describe '#action_id' do
      it 'returns the action_id' do
        expect(handler.action_id).to eq('approve_button')
      end
    end

    describe '#action_value' do
      it 'returns the value' do
        expect(handler.action_value).to eq('request_789')
      end
    end

    describe '#block_id' do
      it 'returns the block_id' do
        expect(handler.block_id).to eq('approval_block')
      end
    end

    describe '#trigger_id' do
      it 'returns the trigger_id' do
        expect(handler.trigger_id).to eq('trigger123')
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/handlers/action_handler_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/handlers/action_handler.rb
module BoltRb
  module Handlers
    class ActionHandler < Base
      class << self
        def action(action_id, block_id: nil)
          @matcher_config = {
            type: :action,
            action_id: action_id,
            block_id: block_id
          }
        end

        def matches?(payload)
          return false unless matcher_config
          return false unless payload['type'] == 'block_actions'

          actions = payload['actions'] || []
          actions.any? do |action|
            action_matches?(action) && block_matches?(action)
          end
        end

        private

        def action_matches?(action)
          if matcher_config[:action_id].is_a?(Regexp)
            matcher_config[:action_id].match?(action['action_id'])
          else
            action['action_id'] == matcher_config[:action_id]
          end
        end

        def block_matches?(action)
          return true if matcher_config[:block_id].nil?

          if matcher_config[:block_id].is_a?(Regexp)
            matcher_config[:block_id].match?(action['block_id'])
          else
            action['block_id'] == matcher_config[:block_id]
          end
        end
      end

      def action
        payload['actions']&.first
      end

      def action_id
        action&.dig('action_id')
      end

      def action_value
        action&.dig('value')
      end

      def block_id
        action&.dig('block_id')
      end

      def trigger_id
        payload['trigger_id']
      end
    end
  end

  ActionHandler = Handlers::ActionHandler
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require)
require_relative 'bolt_rb/handlers/action_handler'
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/handlers/action_handler_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add ActionHandler with action DSL and regex support"
```

---

### Task 8: Shortcut Handler

**Files:**
- Create: `lib/bolt_rb/handlers/shortcut_handler.rb`
- Create: `spec/bolt_rb/handlers/shortcut_handler_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/handlers/shortcut_handler_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::ShortcutHandler do
  describe '.shortcut' do
    let(:handler_class) do
      Class.new(described_class) do
        shortcut 'create_ticket'
      end
    end

    it 'sets matcher_config type to :shortcut' do
      expect(handler_class.matcher_config[:type]).to eq(:shortcut)
    end

    it 'sets the callback_id' do
      expect(handler_class.matcher_config[:callback_id]).to eq('create_ticket')
    end
  end

  describe '.matches?' do
    let(:handler_class) do
      Class.new(described_class) do
        shortcut 'create_ticket'
      end
    end

    it 'matches global shortcut' do
      payload = { 'type' => 'shortcut', 'callback_id' => 'create_ticket' }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'matches message shortcut' do
      payload = { 'type' => 'message_action', 'callback_id' => 'create_ticket' }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'does not match wrong callback_id' do
      payload = { 'type' => 'shortcut', 'callback_id' => 'other_action' }
      expect(handler_class.matches?(payload)).to be false
    end

    context 'with regex' do
      let(:handler_class) do
        Class.new(described_class) do
          shortcut /^create_/
        end
      end

      it 'matches when pattern matches' do
        payload = { 'type' => 'shortcut', 'callback_id' => 'create_issue' }
        expect(handler_class.matches?(payload)).to be true
      end
    end
  end

  describe 'instance methods' do
    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { ->(_) {} }

    context 'global shortcut' do
      let(:payload) do
        {
          'type' => 'shortcut',
          'callback_id' => 'create_ticket',
          'user' => { 'id' => 'U123' },
          'trigger_id' => 'trigger123'
        }
      end
      let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
      let(:handler_class) do
        Class.new(described_class) do
          shortcut 'create_ticket'

          def handle
            # no-op
          end
        end
      end

      subject(:handler) { handler_class.new(context) }

      describe '#callback_id' do
        it 'returns the callback_id' do
          expect(handler.callback_id).to eq('create_ticket')
        end
      end

      describe '#trigger_id' do
        it 'returns the trigger_id' do
          expect(handler.trigger_id).to eq('trigger123')
        end
      end

      describe '#shortcut_type' do
        it 'returns :global for global shortcuts' do
          expect(handler.shortcut_type).to eq(:global)
        end
      end
    end

    context 'message shortcut' do
      let(:payload) do
        {
          'type' => 'message_action',
          'callback_id' => 'quote_message',
          'user' => { 'id' => 'U123' },
          'channel' => { 'id' => 'C456' },
          'message' => {
            'text' => 'Original message text',
            'user' => 'U789',
            'ts' => '1234.5678'
          },
          'trigger_id' => 'trigger456'
        }
      end
      let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
      let(:handler_class) do
        Class.new(described_class) do
          shortcut 'quote_message'

          def handle
            # no-op
          end
        end
      end

      subject(:handler) { handler_class.new(context) }

      describe '#shortcut_type' do
        it 'returns :message for message shortcuts' do
          expect(handler.shortcut_type).to eq(:message)
        end
      end

      describe '#message' do
        it 'returns the message object' do
          expect(handler.message).to eq(payload['message'])
        end
      end

      describe '#message_text' do
        it 'returns the message text' do
          expect(handler.message_text).to eq('Original message text')
        end
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/handlers/shortcut_handler_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/handlers/shortcut_handler.rb
module BoltRb
  module Handlers
    class ShortcutHandler < Base
      SHORTCUT_TYPES = %w[shortcut message_action].freeze

      class << self
        def shortcut(callback_id)
          @matcher_config = {
            type: :shortcut,
            callback_id: callback_id
          }
        end

        def matches?(payload)
          return false unless matcher_config
          return false unless SHORTCUT_TYPES.include?(payload['type'])

          if matcher_config[:callback_id].is_a?(Regexp)
            matcher_config[:callback_id].match?(payload['callback_id'])
          else
            payload['callback_id'] == matcher_config[:callback_id]
          end
        end
      end

      def callback_id
        payload['callback_id']
      end

      def trigger_id
        payload['trigger_id']
      end

      def shortcut_type
        payload['type'] == 'message_action' ? :message : :global
      end

      def message
        payload['message']
      end

      def message_text
        message&.dig('text')
      end
    end
  end

  ShortcutHandler = Handlers::ShortcutHandler
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require)
require_relative 'bolt_rb/handlers/shortcut_handler'
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/handlers/shortcut_handler_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add ShortcutHandler for global and message shortcuts"
```

---

### Task 9: Middleware System

**Files:**
- Create: `lib/bolt_rb/middleware/base.rb`
- Create: `lib/bolt_rb/middleware/chain.rb`
- Modify: `lib/bolt_rb/middleware/logging.rb`
- Create: `spec/bolt_rb/middleware/chain_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/middleware/chain_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Middleware::Chain do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:payload) { { 'event' => { 'type' => 'message' } } }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }

  describe '#call' do
    it 'calls the block when no middleware' do
      called = false
      described_class.new([]).call(context) { called = true }
      expect(called).to be true
    end

    it 'runs middleware in order' do
      order = []

      middleware1 = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          order << :first_before
          block.call
          order << :first_after
        end
      end

      middleware2 = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          order << :second_before
          block.call
          order << :second_after
        end
      end

      described_class.new([middleware1, middleware2]).call(context) do
        order << :handler
      end

      expect(order).to eq([:first_before, :second_before, :handler, :second_after, :first_after])
    end

    it 'stops chain when middleware does not yield' do
      blocking_middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          # Don't call block - stops chain
        end
      end

      called = false
      described_class.new([blocking_middleware]).call(context) { called = true }
      expect(called).to be false
    end

    it 'passes context to middleware' do
      received_context = nil

      middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          received_context = ctx
          block.call
        end
      end

      described_class.new([middleware]).call(context) {}
      expect(received_context).to eq(context)
    end
  end
end

RSpec.describe BoltRb::Middleware::Base do
  describe '#call' do
    it 'yields by default' do
      called = false
      described_class.new.call(nil) { called = true }
      expect(called).to be true
    end
  end
end

RSpec.describe BoltRb::Middleware::Logging do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:payload) { { 'event' => { 'type' => 'message' } } }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(BoltRb).to receive(:logger).and_return(logger)
  end

  describe '#call' do
    it 'logs the event type' do
      described_class.new.call(context) {}
      expect(logger).to have_received(:info).at_least(:once)
    end

    it 'yields to next middleware' do
      called = false
      described_class.new.call(context) { called = true }
      expect(called).to be true
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/middleware/chain_spec.rb`
Expected: FAIL

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/middleware/base.rb
module BoltRb
  module Middleware
    class Base
      def call(context)
        yield if block_given?
      end
    end
  end
end
```

```ruby
# lib/bolt_rb/middleware/chain.rb
module BoltRb
  module Middleware
    class Chain
      def initialize(middleware_classes)
        @middleware_classes = middleware_classes
      end

      def call(context, &block)
        chain = @middleware_classes.map(&:new)
        run_chain(chain, context, &block)
      end

      private

      def run_chain(chain, context, &block)
        if chain.empty?
          block.call
        else
          middleware = chain.shift
          middleware.call(context) do
            run_chain(chain, context, &block)
          end
        end
      end
    end
  end
end
```

```ruby
# lib/bolt_rb/middleware/logging.rb
module BoltRb
  module Middleware
    class Logging < Base
      def call(context)
        event_type = determine_event_type(context.payload)
        BoltRb.logger.info "[BoltRb] Processing #{event_type}"
        started = Time.now

        yield if block_given?

        elapsed = ((Time.now - started) * 1000).round(2)
        BoltRb.logger.info "[BoltRb] Completed #{event_type} in #{elapsed}ms"
      end

      private

      def determine_event_type(payload)
        if payload['event']
          "event:#{payload['event']['type']}"
        elsif payload['command']
          "command:#{payload['command']}"
        elsif payload['type'] == 'block_actions'
          action_ids = payload['actions']&.map { |a| a['action_id'] }&.join(',')
          "action:#{action_ids}"
        elsif payload['type'] == 'shortcut' || payload['type'] == 'message_action'
          "shortcut:#{payload['callback_id']}"
        else
          "unknown"
        end
      end
    end
  end
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb
require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/base'
require_relative 'bolt_rb/middleware/chain'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'
require_relative 'bolt_rb/context'
require_relative 'bolt_rb/handlers/base'
require_relative 'bolt_rb/handlers/event_handler'
require_relative 'bolt_rb/handlers/command_handler'
require_relative 'bolt_rb/handlers/action_handler'
require_relative 'bolt_rb/handlers/shortcut_handler'

module BoltRb
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def logger
      configuration.logger
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/middleware/chain_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add middleware system with Chain and Logging"
```

---

### Task 10: Router

**Files:**
- Create: `lib/bolt_rb/router.rb`
- Create: `spec/bolt_rb/router_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/router_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Router do
  subject(:router) { described_class.new }

  let(:message_handler) do
    Class.new(BoltRb::EventHandler) do
      listen_to :message
      def handle; end
    end
  end

  let(:hello_handler) do
    Class.new(BoltRb::EventHandler) do
      listen_to :message, pattern: /hello/i
      def handle; end
    end
  end

  let(:deploy_command) do
    Class.new(BoltRb::CommandHandler) do
      command '/deploy'
      def handle; end
    end
  end

  let(:approve_action) do
    Class.new(BoltRb::ActionHandler) do
      action 'approve'
      def handle; end
    end
  end

  let(:create_shortcut) do
    Class.new(BoltRb::ShortcutHandler) do
      shortcut 'create_ticket'
      def handle; end
    end
  end

  describe '#register' do
    it 'registers event handlers' do
      router.register(message_handler)
      expect(router.handler_count).to eq(1)
    end

    it 'registers command handlers' do
      router.register(deploy_command)
      expect(router.handler_count).to eq(1)
    end

    it 'registers action handlers' do
      router.register(approve_action)
      expect(router.handler_count).to eq(1)
    end

    it 'registers shortcut handlers' do
      router.register(create_shortcut)
      expect(router.handler_count).to eq(1)
    end
  end

  describe '#route' do
    before do
      router.register(message_handler)
      router.register(hello_handler)
      router.register(deploy_command)
      router.register(approve_action)
      router.register(create_shortcut)
    end

    context 'events' do
      it 'returns matching event handlers' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'hello world' } }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(message_handler, hello_handler)
      end

      it 'filters by pattern' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'goodbye' } }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(message_handler)
      end
    end

    context 'commands' do
      it 'returns matching command handlers' do
        payload = { 'command' => '/deploy', 'text' => 'production' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(deploy_command)
      end

      it 'returns empty for non-matching commands' do
        payload = { 'command' => '/rollback' }
        handlers = router.route(payload)
        expect(handlers).to be_empty
      end
    end

    context 'actions' do
      it 'returns matching action handlers' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve' }]
        }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(approve_action)
      end
    end

    context 'shortcuts' do
      it 'returns matching shortcut handlers' do
        payload = { 'type' => 'shortcut', 'callback_id' => 'create_ticket' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(create_shortcut)
      end

      it 'returns matching message shortcut handlers' do
        payload = { 'type' => 'message_action', 'callback_id' => 'create_ticket' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(create_shortcut)
      end
    end
  end

  describe '#clear' do
    it 'removes all registered handlers' do
      router.register(message_handler)
      router.clear
      expect(router.handler_count).to eq(0)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/router_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/router.rb
module BoltRb
  class Router
    def initialize
      @handlers = []
    end

    def register(handler_class)
      @handlers << handler_class
    end

    def route(payload)
      @handlers.select { |handler| handler.matches?(payload) }
    end

    def handler_count
      @handlers.length
    end

    def clear
      @handlers.clear
    end
  end
end
```

**Step 4: Update main entry point and add router accessor**

```ruby
# lib/bolt_rb.rb (add require and accessor)
require_relative 'bolt_rb/router'

# In the class << self block, add:
def router
  @router ||= Router.new
end

def reset_router!
  @router = Router.new
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/router_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Router for handler registration and dispatch"
```

---

### Task 11: Testing Utilities

**Files:**
- Create: `lib/bolt_rb/testing.rb`
- Create: `lib/bolt_rb/testing/payload_factory.rb`
- Create: `lib/bolt_rb/testing/rspec_helpers.rb`
- Create: `spec/bolt_rb/testing/payload_factory_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/testing/payload_factory_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::Testing::PayloadFactory do
  describe '.message' do
    it 'creates a message event payload' do
      payload = described_class.message(text: 'hello')
      expect(payload['event']['type']).to eq('message')
      expect(payload['event']['text']).to eq('hello')
    end

    it 'allows customizing user' do
      payload = described_class.message(text: 'hi', user: 'U999')
      expect(payload['event']['user']).to eq('U999')
    end

    it 'allows customizing channel' do
      payload = described_class.message(text: 'hi', channel: 'C999')
      expect(payload['event']['channel']).to eq('C999')
    end
  end

  describe '.app_mention' do
    it 'creates an app_mention event payload' do
      payload = described_class.app_mention(text: '<@U123> help')
      expect(payload['event']['type']).to eq('app_mention')
      expect(payload['event']['text']).to eq('<@U123> help')
    end
  end

  describe '.command' do
    it 'creates a command payload' do
      payload = described_class.command(command: '/deploy', text: 'production')
      expect(payload['command']).to eq('/deploy')
      expect(payload['text']).to eq('production')
    end

    it 'includes response_url' do
      payload = described_class.command(command: '/test')
      expect(payload['response_url']).to start_with('https://hooks.slack.com')
    end

    it 'includes trigger_id' do
      payload = described_class.command(command: '/test')
      expect(payload['trigger_id']).not_to be_nil
    end
  end

  describe '.action' do
    it 'creates a block_actions payload' do
      payload = described_class.action(action_id: 'approve', value: '123')
      expect(payload['type']).to eq('block_actions')
      expect(payload['actions'].first['action_id']).to eq('approve')
      expect(payload['actions'].first['value']).to eq('123')
    end

    it 'allows customizing block_id' do
      payload = described_class.action(action_id: 'btn', block_id: 'my_block')
      expect(payload['actions'].first['block_id']).to eq('my_block')
    end
  end

  describe '.shortcut' do
    it 'creates a global shortcut payload' do
      payload = described_class.shortcut(callback_id: 'create_ticket')
      expect(payload['type']).to eq('shortcut')
      expect(payload['callback_id']).to eq('create_ticket')
    end

    it 'allows creating message shortcut' do
      payload = described_class.shortcut(callback_id: 'quote', type: :message)
      expect(payload['type']).to eq('message_action')
    end

    it 'includes message for message shortcuts' do
      payload = described_class.shortcut(
        callback_id: 'quote',
        type: :message,
        message_text: 'Original text'
      )
      expect(payload['message']['text']).to eq('Original text')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/testing/payload_factory_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/testing/payload_factory.rb
module BoltRb
  module Testing
    class PayloadFactory
      class << self
        def message(text:, user: 'U123TEST', channel: 'C456TEST', ts: nil, thread_ts: nil)
          {
            'type' => 'event_callback',
            'event' => {
              'type' => 'message',
              'text' => text,
              'user' => user,
              'channel' => channel,
              'ts' => ts || generate_ts,
              'thread_ts' => thread_ts
            }.compact
          }
        end

        def app_mention(text:, user: 'U123TEST', channel: 'C456TEST')
          {
            'type' => 'event_callback',
            'event' => {
              'type' => 'app_mention',
              'text' => text,
              'user' => user,
              'channel' => channel,
              'ts' => generate_ts
            }
          }
        end

        def command(command:, text: '', user: 'U123TEST', channel: 'C456TEST')
          {
            'command' => command,
            'text' => text,
            'user_id' => user,
            'channel_id' => channel,
            'response_url' => 'https://hooks.slack.com/commands/T123/456/xxx',
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }
        end

        def action(action_id:, value: nil, user: 'U123TEST', block_id: nil, channel: 'C456TEST')
          {
            'type' => 'block_actions',
            'user' => { 'id' => user },
            'channel' => { 'id' => channel },
            'actions' => [{
              'action_id' => action_id,
              'block_id' => block_id || 'block_1',
              'value' => value
            }.compact],
            'response_url' => 'https://hooks.slack.com/actions/T123/456/xxx',
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }
        end

        def shortcut(callback_id:, user: 'U123TEST', type: :global, message_text: nil)
          payload = {
            'type' => type == :message ? 'message_action' : 'shortcut',
            'callback_id' => callback_id,
            'user' => { 'id' => user },
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }

          if type == :message
            payload['channel'] = { 'id' => 'C456TEST' }
            payload['message'] = {
              'type' => 'message',
              'text' => message_text || 'Original message',
              'user' => 'U789MSG',
              'ts' => generate_ts
            }
          end

          payload
        end

        private

        def generate_ts
          "#{Time.now.to_i}.#{SecureRandom.hex(3)}"
        end
      end
    end
  end
end
```

```ruby
# lib/bolt_rb/testing/rspec_helpers.rb
module BoltRb
  module Testing
    module RSpecHelpers
      def build_context(payload, client: nil, ack: nil)
        BoltRb::Context.new(
          payload: payload,
          client: client || mock_slack_client,
          ack: ack || ->(_) {}
        )
      end

      def mock_slack_client
        client = instance_double(Slack::Web::Client)
        allow(client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '123.456' })
        allow(client).to receive(:chat_update).and_return({ 'ok' => true })
        allow(client).to receive(:views_open).and_return({ 'ok' => true })
        allow(client).to receive(:views_update).and_return({ 'ok' => true })
        client
      end

      def payload
        BoltRb::Testing::PayloadFactory
      end
    end
  end
end
```

```ruby
# lib/bolt_rb/testing.rb
require_relative 'testing/payload_factory'
require_relative 'testing/rspec_helpers'

module BoltRb
  module Testing
  end
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require at the end)
require_relative 'bolt_rb/testing'
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/testing/payload_factory_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add testing utilities with PayloadFactory and RSpec helpers"
```

---

### Task 12: App Class (Main Entry Point)

**Files:**
- Create: `lib/bolt_rb/app.rb`
- Create: `spec/bolt_rb/app_spec.rb`
- Modify: `lib/bolt_rb.rb`

**Step 1: Write the failing test**

```ruby
# spec/bolt_rb/app_spec.rb
require 'spec_helper'

RSpec.describe BoltRb::App do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:socket_client) { instance_double(Slack::RealTime::Client) }

  before do
    BoltRb.reset_configuration!
    BoltRb.reset_router!
    BoltRb.configure do |config|
      config.bot_token = 'xoxb-test'
      config.app_token = 'xapp-test'
    end

    allow(Slack::Web::Client).to receive(:new).and_return(web_client)
    allow(Slack::RealTime::Client).to receive(:new).and_return(socket_client)
    allow(socket_client).to receive(:on)
  end

  describe '#initialize' do
    it 'creates a web client' do
      described_class.new
      expect(Slack::Web::Client).to have_received(:new).with(token: 'xoxb-test')
    end

    it 'creates a socket client' do
      described_class.new
      expect(Slack::RealTime::Client).to have_received(:new).with(token: 'xapp-test')
    end
  end

  describe '#process_event' do
    let(:app) { described_class.new }

    let(:message_handler) do
      Class.new(BoltRb::EventHandler) do
        listen_to :message

        def handle
          say "Received: #{text}"
        end
      end
    end

    before do
      BoltRb.router.register(message_handler)
      allow(web_client).to receive(:chat_postMessage)
    end

    it 'routes event to matching handler' do
      payload = { 'event' => { 'type' => 'message', 'text' => 'hello', 'channel' => 'C123' } }

      app.process_event(payload)

      expect(web_client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Received: hello')
      )
    end

    it 'runs global middleware' do
      middleware_called = false

      test_middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |context, &block|
          middleware_called = true
          block.call
        end
      end

      BoltRb.configuration.middleware.clear
      BoltRb.configuration.use(test_middleware)

      payload = { 'event' => { 'type' => 'message', 'text' => 'hi', 'channel' => 'C123' } }
      app.process_event(payload)

      expect(middleware_called).to be true
    end

    it 'calls error handler on exception' do
      error_received = nil
      BoltRb.configuration.error_handler = ->(e, _) { error_received = e }

      broken_handler = Class.new(BoltRb::EventHandler) do
        listen_to :app_mention
        def handle
          raise 'Boom!'
        end
      end

      BoltRb.router.register(broken_handler)

      payload = { 'event' => { 'type' => 'app_mention', 'text' => 'test', 'channel' => 'C123' } }
      app.process_event(payload)

      expect(error_received).to be_a(RuntimeError)
      expect(error_received.message).to eq('Boom!')
    end

    it 'continues processing other handlers when one fails' do
      first_handler_called = false

      working_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        define_method(:handle) { first_handler_called = true }
      end

      broken_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        def handle
          raise 'Boom!'
        end
      end

      BoltRb.router.clear
      BoltRb.router.register(working_handler)
      BoltRb.router.register(broken_handler)
      BoltRb.configuration.error_handler = ->(_e, _p) {}

      payload = { 'event' => { 'type' => 'message', 'text' => 'hi', 'channel' => 'C123' } }
      app.process_event(payload)

      expect(first_handler_called).to be true
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/bolt_rb/app_spec.rb`
Expected: FAIL with uninitialized constant

**Step 3: Write implementation**

```ruby
# lib/bolt_rb/app.rb
require 'slack-ruby-client'

module BoltRb
  class App
    attr_reader :client, :router, :config

    def initialize
      @config = BoltRb.configuration
      @router = BoltRb.router
      @client = Slack::Web::Client.new(token: config.bot_token)
      @socket_client = Slack::RealTime::Client.new(token: config.app_token)

      setup_socket_handlers
    end

    def start
      load_handlers
      BoltRb.logger.info "[BoltRb] Connecting to Slack..."
      @socket_client.start!
    end

    def stop
      BoltRb.logger.info "[BoltRb] Disconnecting..."
      @socket_client.stop!
    end

    def process_event(payload)
      handlers = router.route(payload)
      return if handlers.empty?

      context = build_context(payload)

      Middleware::Chain.new(config.middleware).call(context) do
        handlers.each do |handler_class|
          execute_handler(handler_class, context)
        end
      end
    end

    private

    def setup_socket_handlers
      @socket_client.on :message do |raw_event|
        process_event(raw_event)
      end
    end

    def load_handlers
      config.handler_paths.each do |path|
        pattern = File.join(path, '**', '*.rb')
        Dir.glob(pattern).sort.each do |file|
          require file
        end
      end

      BoltRb.logger.info "[BoltRb] Loaded #{router.handler_count} handlers"
    end

    def build_context(payload)
      Context.new(
        payload: payload,
        client: client,
        ack: build_ack_fn(payload)
      )
    end

    def build_ack_fn(payload)
      # For Socket Mode, ack is handled differently than HTTP
      # This is a placeholder - real implementation depends on socket-mode gem
      ->(_response) {}
    end

    def execute_handler(handler_class, context)
      handler_class.new(context).call
    rescue StandardError => e
      BoltRb.logger.error "[BoltRb] Error in #{handler_class}: #{e.message}"
      BoltRb.logger.error e.backtrace.first(5).join("\n")
      config.error_handler&.call(e, context.payload)
    end
  end
end
```

**Step 4: Update main entry point**

```ruby
# lib/bolt_rb.rb (add require)
require_relative 'bolt_rb/app'

# Add to class << self block:
def reset_router!
  @router = Router.new
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/bolt_rb/app_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add App class for Socket Mode connection"
```

---

### Task 13: Final Integration - Full lib/bolt_rb.rb

**Files:**
- Modify: `lib/bolt_rb.rb` (final version)
- Create: `spec/integration/handler_flow_spec.rb`

**Step 1: Write integration test**

```ruby
# spec/integration/handler_flow_spec.rb
require 'spec_helper'

RSpec.describe 'Handler Integration', type: :integration do
  include BoltRb::Testing::RSpecHelpers

  before do
    BoltRb.reset_configuration!
    BoltRb.reset_router!
  end

  describe 'EventHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::EventHandler) do
        listen_to :message, pattern: /hello/i

        def handle
          say "Hi <@#{user}>!"
        end
      end
    end

    it 'handles matching events' do
      BoltRb.router.register(handler_class)

      context = build_context(payload.message(text: 'hello world', user: 'U999'))
      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Hi <@U999>!')
      )
    end
  end

  describe 'CommandHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::CommandHandler) do
        command '/greet'

        def handle
          ack "Greeting #{command_text}..."
          say "Hello, #{command_text}!"
        end
      end
    end

    it 'handles matching commands' do
      BoltRb.router.register(handler_class)

      acked_with = nil
      ack_fn = ->(response) { acked_with = response }
      context = build_context(
        payload.command(command: '/greet', text: 'world'),
        ack: ack_fn
      )

      handler_class.new(context).call

      expect(acked_with).to eq('Greeting world...')
      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Hello, world!')
      )
    end
  end

  describe 'ActionHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::ActionHandler) do
        action 'confirm_button'

        def handle
          ack
          say "Confirmed: #{action_value}"
        end
      end
    end

    it 'handles matching actions' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.action(action_id: 'confirm_button', value: 'item_123')
      )

      handler_class.new(context).call

      expect(context).to be_acked
      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Confirmed: item_123')
      )
    end
  end

  describe 'ShortcutHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::ShortcutHandler) do
        shortcut 'create_task'

        def handle
          ack
          client.views_open(
            trigger_id: trigger_id,
            view: { type: 'modal', title: { type: 'plain_text', text: 'New Task' } }
          )
        end
      end
    end

    it 'handles matching shortcuts' do
      BoltRb.router.register(handler_class)

      context = build_context(payload.shortcut(callback_id: 'create_task'))
      handler_class.new(context).call

      expect(context).to be_acked
      expect(context.client).to have_received(:views_open).with(
        hash_including(view: hash_including(type: 'modal'))
      )
    end
  end

  describe 'Middleware integration' do
    let(:admin_middleware) do
      Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |context, &block|
          if context.user == 'UADMIN'
            block.call
          else
            context.say 'Not authorized'
          end
        end
      end
    end

    let(:handler_class) do
      admin_mw = admin_middleware
      Class.new(BoltRb::CommandHandler) do
        command '/admin'
        use admin_mw

        def handle
          ack
          say 'Admin action executed'
        end
      end
    end

    it 'allows authorized users' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.command(command: '/admin', user: 'UADMIN')
      )

      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Admin action executed')
      )
    end

    it 'blocks unauthorized users' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.command(command: '/admin', user: 'URANDO')
      )

      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Not authorized')
      )
      expect(context.client).not_to have_received(:chat_postMessage).with(
        hash_including(text: 'Admin action executed')
      )
    end
  end
end
```

**Step 2: Run integration test**

Run: `bundle exec rspec spec/integration/handler_flow_spec.rb`
Expected: All tests PASS

**Step 3: Create final lib/bolt_rb.rb**

```ruby
# lib/bolt_rb.rb
require 'logger'

require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/base'
require_relative 'bolt_rb/middleware/chain'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'
require_relative 'bolt_rb/context'
require_relative 'bolt_rb/handlers/base'
require_relative 'bolt_rb/handlers/event_handler'
require_relative 'bolt_rb/handlers/command_handler'
require_relative 'bolt_rb/handlers/action_handler'
require_relative 'bolt_rb/handlers/shortcut_handler'
require_relative 'bolt_rb/router'
require_relative 'bolt_rb/app'
require_relative 'bolt_rb/testing'

module BoltRb
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def router
      @router ||= Router.new
    end

    def reset_router!
      @router = Router.new
    end

    def logger
      configuration.logger
    end
  end
end
```

**Step 4: Run all tests**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: complete bolt-rb integration with full test coverage"
```

---

### Task 14: Example Handler and Binstub

**Files:**
- Create: `examples/simple_bot/Gemfile`
- Create: `examples/simple_bot/bot.rb`
- Create: `examples/simple_bot/handlers/greeting_handler.rb`
- Create: `examples/simple_bot/handlers/deploy_command.rb`

**Step 1: Create example Gemfile**

```ruby
# examples/simple_bot/Gemfile
source 'https://rubygems.org'

gem 'bolt_rb', path: '../..'
```

**Step 2: Create example bot runner**

```ruby
#!/usr/bin/env ruby
# examples/simple_bot/bot.rb

require 'bundler/setup'
require 'bolt_rb'

BoltRb.configure do |config|
  config.bot_token = ENV.fetch('SLACK_BOT_TOKEN')
  config.app_token = ENV.fetch('SLACK_APP_TOKEN')
  config.handler_paths = [File.expand_path('handlers', __dir__)]
end

app = BoltRb::App.new

%w[INT TERM].each do |signal|
  Signal.trap(signal) do
    puts "\nShutting down..."
    app.stop
    exit 0
  end
end

puts "Starting bot..."
app.start
```

**Step 3: Create example handlers**

```ruby
# examples/simple_bot/handlers/greeting_handler.rb
class GreetingHandler < BoltRb::EventHandler
  listen_to :message, pattern: /hello/i

  def handle
    say "Hey there <@#{user}>! Welcome to bolt-rb."
  end
end
```

```ruby
# examples/simple_bot/handlers/deploy_command.rb
class DeployCommand < BoltRb::CommandHandler
  command '/deploy'

  def handle
    ack "Deploying #{command_text}..."

    # Simulate deploy
    sleep 1

    say "Deployed #{command_text} successfully!"
  end
end
```

**Step 4: Commit**

```bash
git add -A
git commit -m "docs: add example simple_bot with handlers"
```

---

## Summary

This plan creates a fully functional bolt-rb gem with:

1. **Gem skeleton** with RSpec testing setup
2. **Configuration** module for tokens and settings
3. **Context** class for payload access and response methods
4. **Handler base classes** for events, commands, actions, and shortcuts
5. **Router** for auto-registration and event dispatch
6. **Middleware system** with chain execution and logging
7. **Testing utilities** with payload factories and RSpec helpers
8. **App class** for Socket Mode connection
9. **Example bot** demonstrating usage

Total: ~14 tasks, each with TDD approach (write test, verify fail, implement, verify pass, commit).
