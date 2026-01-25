# frozen_string_literal: true

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
