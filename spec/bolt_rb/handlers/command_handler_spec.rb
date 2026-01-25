# frozen_string_literal: true

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
