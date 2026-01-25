# frozen_string_literal: true

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
