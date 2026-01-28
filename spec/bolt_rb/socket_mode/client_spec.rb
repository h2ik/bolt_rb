# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::SocketMode::Client do
  let(:app_token) { 'xapp-test-token' }
  let(:logger) { instance_double(Logger, info: nil, debug: nil, warn: nil, error: nil) }

  describe '#initialize' do
    it 'sets the app token' do
      client = described_class.new(app_token: app_token)
      expect(client.app_token).to eq(app_token)
    end

    it 'accepts a custom logger' do
      client = described_class.new(app_token: app_token, logger: logger)
      expect(client.logger).to eq(logger)
    end

    it 'defaults to not running' do
      client = described_class.new(app_token: app_token)
      expect(client.running?).to be false
    end
  end

  describe '#on_message' do
    it 'registers a message handler' do
      client = described_class.new(app_token: app_token, logger: logger)
      handler_called = false

      client.on_message { handler_called = true }

      # Access private method for testing
      client.send(:dispatch_event, { type: 'test' })

      expect(handler_called).to be true
    end

    it 'passes event data to the handler' do
      client = described_class.new(app_token: app_token, logger: logger)
      received_data = nil

      client.on_message { |data| received_data = data }

      test_data = { type: 'events_api', payload: { foo: 'bar' } }
      client.send(:dispatch_event, test_data)

      expect(received_data).to eq(test_data)
    end
  end

  describe '#stop' do
    it 'sets running to false' do
      client = described_class.new(app_token: app_token, logger: logger)
      # Simulate running state
      client.instance_variable_set(:@running, true)

      client.stop

      expect(client.running?).to be false
    end
  end

  describe 'WebSocket URL acquisition' do
    let(:client) { described_class.new(app_token: app_token, logger: logger) }
    let(:success_response) do
      { 'ok' => true, 'url' => 'wss://wss-primary.slack.com/link/?ticket=xxx' }
    end
    let(:error_response) do
      { 'ok' => false, 'error' => 'invalid_auth' }
    end

    before do
      stub_request(:post, 'https://slack.com/api/apps.connections.open')
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'obtains websocket URL from Slack API' do
      url = client.send(:obtain_websocket_url)
      expect(url).to eq('wss://wss-primary.slack.com/link/?ticket=xxx')
    end

    it 'sends authorization header' do
      client.send(:obtain_websocket_url)

      expect(WebMock).to have_requested(:post, 'https://slack.com/api/apps.connections.open')
        .with(headers: { 'Authorization' => "Bearer #{app_token}" })
    end

    it 'raises error on failed response' do
      stub_request(:post, 'https://slack.com/api/apps.connections.open')
        .to_return(status: 200, body: error_response.to_json)

      expect { client.send(:obtain_websocket_url) }
        .to raise_error(RuntimeError, /invalid_auth/)
    end
  end

  describe 'acknowledgement' do
    let(:client) { described_class.new(app_token: app_token, logger: logger) }
    let(:websocket) { instance_double(WebSocket::Client::Simple::Client) }

    before do
      client.instance_variable_set(:@websocket, websocket)
      allow(websocket).to receive(:open?).and_return(true)
      allow(websocket).to receive(:send)
    end

    it 'sends ack with envelope_id' do
      client.send(:acknowledge, 'env-123')

      expect(websocket).to have_received(:send).with('{"envelope_id":"env-123"}')
    end

    it 'does not send ack when websocket is closed' do
      allow(websocket).to receive(:open?).and_return(false)

      client.send(:acknowledge, 'env-123')

      expect(websocket).not_to have_received(:send)
    end
  end

  describe 'ping handling' do
    let(:client) { described_class.new(app_token: app_token, logger: logger) }
    let(:websocket) { instance_double(WebSocket::Client::Simple::Client) }

    before do
      client.instance_variable_set(:@websocket, websocket)
      allow(websocket).to receive(:open?).and_return(true)
      allow(websocket).to receive(:send)
    end

    it 'responds to ping with pong' do
      client.send(:handle_ping, { 'type' => 'ping' })

      expect(websocket).to have_received(:send).with('{"type":"pong"}')
    end

    it 'echoes back the num field when present' do
      client.send(:handle_ping, { 'type' => 'ping', 'num' => 42 })

      expect(websocket).to have_received(:send).with('{"type":"pong","num":42}')
    end

    it 'does not send pong when websocket is closed' do
      allow(websocket).to receive(:open?).and_return(false)

      client.send(:handle_ping, { 'type' => 'ping', 'num' => 123 })

      expect(websocket).not_to have_received(:send)
    end
  end

  describe 'message handling' do
    let(:client) { described_class.new(app_token: app_token, logger: logger) }
    let(:websocket) { instance_double(WebSocket::Client::Simple::Client) }

    before do
      client.instance_variable_set(:@websocket, websocket)
      allow(websocket).to receive(:open?).and_return(true)
      allow(websocket).to receive(:send)
    end

    it 'handles ping messages and does not dispatch to handlers' do
      handler_called = false
      client.on_message { handler_called = true }

      msg = double('message', type: :text, data: '{"type":"ping","num":1}')
      client.send(:handle_message, msg)

      expect(handler_called).to be false
      expect(websocket).to have_received(:send).with('{"type":"pong","num":1}')
    end

    it 'handles hello messages and does not dispatch to handlers' do
      handler_called = false
      client.on_message { handler_called = true }

      msg = double('message', type: :text, data: '{"type":"hello"}')
      client.send(:handle_message, msg)

      expect(handler_called).to be false
    end

    it 'dispatches regular events to handlers' do
      received_data = nil
      client.on_message { |data| received_data = data }

      msg = double('message', type: :text, data: '{"type":"events_api","envelope_id":"env-456","payload":{"foo":"bar"}}')
      client.send(:handle_message, msg)

      expect(received_data).to include('type' => 'events_api', 'envelope_id' => 'env-456')
    end

    it 'updates last_message_at timestamp on message receipt' do
      before_time = Time.now
      msg = double('message', type: :text, data: '{"type":"hello"}')
      client.send(:handle_message, msg)
      after_time = Time.now

      last_msg_at = client.instance_variable_get(:@last_message_at)
      expect(last_msg_at).to be >= before_time
      expect(last_msg_at).to be <= after_time
    end

    it 'handles WebSocket ping frames with pong frame response' do
      msg = double('message', type: :ping, data: 'Ping from applink-14')
      client.send(:handle_message, msg)

      # Should respond with pong frame echoing the payload
      expect(websocket).to have_received(:send).with('Ping from applink-14', type: :pong)
    end

    it 'does not dispatch WebSocket ping frames to handlers' do
      handler_called = false
      client.on_message { handler_called = true }

      msg = double('message', type: :ping, data: 'Ping from applink-14')
      client.send(:handle_message, msg)

      expect(handler_called).to be false
    end
  end

  describe 'connection staleness detection' do
    let(:client) { described_class.new(app_token: app_token, logger: logger) }
    let(:websocket) { instance_double(WebSocket::Client::Simple::Client) }

    before do
      client.instance_variable_set(:@websocket, websocket)
      allow(websocket).to receive(:open?).and_return(true)
      allow(websocket).to receive(:close)
    end

    describe '#connection_stale?' do
      it 'returns false when websocket is not open' do
        allow(websocket).to receive(:open?).and_return(false)
        client.instance_variable_set(:@last_message_at, Time.now - 100)

        expect(client.send(:connection_stale?)).to be false
      end

      it 'returns false when last_message_at is nil' do
        client.instance_variable_set(:@last_message_at, nil)

        expect(client.send(:connection_stale?)).to be false
      end

      it 'returns false when message received recently' do
        client.instance_variable_set(:@last_message_at, Time.now - 10)

        expect(client.send(:connection_stale?)).to be false
      end

      it 'returns true when no message received within threshold' do
        stale_time = Time.now - (described_class::CONNECTION_STALE_THRESHOLD + 1)
        client.instance_variable_set(:@last_message_at, stale_time)

        expect(client.send(:connection_stale?)).to be true
      end
    end

    describe '#force_reconnect' do
      it 'closes the websocket' do
        client.instance_variable_set(:@last_message_at, Time.now)

        client.send(:force_reconnect)

        expect(websocket).to have_received(:close)
      end

      it 'resets last_message_at to nil' do
        client.instance_variable_set(:@last_message_at, Time.now)

        client.send(:force_reconnect)

        expect(client.instance_variable_get(:@last_message_at)).to be_nil
      end
    end
  end
end
