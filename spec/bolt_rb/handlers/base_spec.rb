# frozen_string_literal: true

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
