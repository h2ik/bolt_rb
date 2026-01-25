# frozen_string_literal: true

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
