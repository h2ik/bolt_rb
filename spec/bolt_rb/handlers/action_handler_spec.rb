# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::ActionHandler do
  describe '.action' do
    let(:handler_class) do
      Class.new(described_class) do
        action 'approve_button'
      end
    end

    it 'sets matcher_config type to :action' do
      expect(handler_class.matcher_config[:type]).to eq(:action)
    end

    it 'sets the action_id' do
      expect(handler_class.matcher_config[:action_id]).to eq('approve_button')
    end

    context 'with block_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve_button', block_id: 'approval_block'
        end
      end

      it 'stores the block_id' do
        expect(handler_class.matcher_config[:block_id]).to eq('approval_block')
      end
    end

    context 'with regex' do
      let(:handler_class) do
        Class.new(described_class) do
          action /^approve_/
        end
      end

      it 'stores regex pattern' do
        expect(handler_class.matcher_config[:action_id]).to eq(/^approve_/)
      end
    end
  end

  describe '.matches?' do
    context 'string action_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve_button'
        end
      end

      it 'matches when action_id matches' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve_button', 'value' => '123' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match wrong action_id' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'reject_button' }]
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'regex action_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action /^approve_/
        end
      end

      it 'matches when pattern matches' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve_request_123' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end
    end

    context 'with block_id' do
      let(:handler_class) do
        Class.new(described_class) do
          action 'approve', block_id: 'approvals'
        end
      end

      it 'matches when both action_id and block_id match' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve', 'block_id' => 'approvals' }]
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match when block_id differs' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve', 'block_id' => 'other' }]
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { ->(_) {} }
    let(:payload) do
      {
        'type' => 'block_actions',
        'user' => { 'id' => 'U123' },
        'channel' => { 'id' => 'C456' },
        'actions' => [{
          'action_id' => 'approve_button',
          'block_id' => 'approval_block',
          'value' => 'request_789'
        }],
        'trigger_id' => 'trigger123',
        'response_url' => 'https://hooks.slack.com/actions/xxx'
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler_class) do
      Class.new(described_class) do
        action 'approve_button'

        def handle
          # no-op
        end
      end
    end

    subject(:handler) { handler_class.new(context) }

    describe '#action' do
      it 'returns the first action' do
        expect(handler.action).to eq(payload['actions'].first)
      end
    end

    describe '#action_id' do
      it 'returns the action_id' do
        expect(handler.action_id).to eq('approve_button')
      end
    end

    describe '#action_value' do
      it 'returns the value' do
        expect(handler.action_value).to eq('request_789')
      end
    end

    describe '#block_id' do
      it 'returns the block_id' do
        expect(handler.block_id).to eq('approval_block')
      end
    end

    describe '#trigger_id' do
      it 'returns the trigger_id' do
        expect(handler.trigger_id).to eq('trigger123')
      end
    end
  end
end
