# frozen_string_literal: true

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
