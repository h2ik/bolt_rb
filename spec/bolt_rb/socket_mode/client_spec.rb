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
end
