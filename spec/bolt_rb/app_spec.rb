# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::App do
  let(:web_client) { instance_double(Slack::Web::Client) }
  let(:socket_client) { instance_double(BoltRb::SocketMode::Client) }

  before do
    BoltRb.reset_configuration!
    BoltRb.reset_router!
    BoltRb.configure do |config|
      config.bot_token = 'xoxb-test'
      config.app_token = 'xapp-test'
    end

    allow(Slack::Web::Client).to receive(:new).and_return(web_client)
    allow(BoltRb::SocketMode::Client).to receive(:new).and_return(socket_client)
    allow(socket_client).to receive(:on_message)
  end

  describe '#initialize' do
    it 'creates a web client' do
      described_class.new
      expect(Slack::Web::Client).to have_received(:new).with(token: 'xoxb-test')
    end

    it 'creates a socket mode client' do
      described_class.new
      expect(BoltRb::SocketMode::Client).to have_received(:new).with(
        hash_including(app_token: 'xapp-test')
      )
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

  describe 'socket event dispatch' do
    let(:app) { described_class.new }
    let(:socket_callback) { @socket_callback }

    before do
      allow(socket_client).to receive(:on_message) { |&block| @socket_callback = block }
      allow(socket_client).to receive(:start)
      allow(socket_client).to receive(:stop)
      allow(web_client).to receive(:chat_postMessage)
      BoltRb.configuration.handler_paths = []
      BoltRb.configuration.worker_threads = 2
    end

    def envelope(text)
      {
        'type' => 'events_api',
        'envelope_id' => 'env-1',
        'payload' => { 'event' => { 'type' => 'message', 'text' => text, 'channel' => 'C1' } }
      }
    end

    def wait_until(seconds = 2)
      deadline = Time.now + seconds
      sleep 0.01 until yield || Time.now > deadline
    end

    it 'runs handlers on a worker thread while the app runs' do
      seen = nil
      handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        define_method(:handle) { seen = Thread.current }
      end
      BoltRb.router.clear
      BoltRb.router.register(handler)

      # socket_client.start is stubbed, so the pool must stay up until we say so
      allow(socket_client).to receive(:start) do
        socket_callback.call(envelope('hi'))
        wait_until { seen }
      end

      app.start
      expect(seen).not_to be_nil
      expect(seen).not_to eq(Thread.current)
    end

    it 'shuts the worker pool down after the socket client stops' do
      app.start
      expect(app.worker_pool.running?).to be false
    end

    it 'finishes in-flight handlers before start returns' do
      done = false
      handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        define_method(:handle) { sleep 0.05; done = true }
      end
      BoltRb.router.clear
      BoltRb.router.register(handler)
      allow(socket_client).to receive(:start) { socket_callback.call(envelope('hi')) }

      app.start
      expect(done).to be true
    end
  end
end
