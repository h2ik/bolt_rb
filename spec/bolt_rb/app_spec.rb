# frozen_string_literal: true

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
