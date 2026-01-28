# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Handlers::ViewClosedHandler do
  describe '.view_closed' do
    let(:handler_class) do
      Class.new(described_class) do
        view_closed 'test_modal'
      end
    end

    it 'sets the matcher config' do
      expect(handler_class.matcher_config).to eq({
        type: :view_closed,
        callback_id: 'test_modal'
      })
    end
  end

  describe '.matches?' do
    context 'with exact callback_id match' do
      let(:handler_class) do
        Class.new(described_class) do
          view_closed 'test_modal'
        end
      end

      it 'returns true for matching view_closed payload' do
        payload = {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'test_modal' }
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'returns false for non-matching callback_id' do
        payload = {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'other_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end

      it 'returns false for view_submission type' do
        payload = {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'test_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end

      it 'returns false for other payload types' do
        payload = { 'type' => 'block_actions' }
        expect(handler_class.matches?(payload)).to be false
      end

      it 'returns false when view is missing' do
        payload = { 'type' => 'view_closed' }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'with regex callback_id' do
      let(:handler_class) do
        Class.new(described_class) do
          view_closed(/^wizard_step_/)
        end
      end

      it 'returns true for matching pattern' do
        payload = {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'wizard_step_3' }
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'returns false for non-matching pattern' do
        payload = {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'settings_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'without matcher config' do
      let(:handler_class) { Class.new(described_class) }

      it 'returns false' do
        payload = {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'test_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end
  end

  describe 'instance methods' do
    let(:handler_class) do
      Class.new(described_class) do
        view_closed 'test_modal'
      end
    end

    let(:client) { instance_double(Slack::Web::Client) }
    let(:ack_fn) { proc {} }
    let(:payload) do
      {
        'type' => 'view_closed',
        'view' => {
          'callback_id' => 'test_modal',
          'private_metadata' => '{"ticket_id":123}'
        },
        'user' => { 'id' => 'U12345' },
        'is_cleared' => false
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler) { handler_class.new(context) }

    describe '#view' do
      it 'returns the view object' do
        expect(handler.view).to eq({
          'callback_id' => 'test_modal',
          'private_metadata' => '{"ticket_id":123}'
        })
      end
    end

    describe '#callback_id' do
      it 'returns the callback_id' do
        expect(handler.callback_id).to eq('test_modal')
      end
    end

    describe '#private_metadata' do
      it 'returns the private_metadata' do
        expect(handler.private_metadata).to eq('{"ticket_id":123}')
      end
    end

    describe '#is_cleared?' do
      it 'returns false when user closed manually' do
        expect(handler.is_cleared?).to be false
      end

      context 'when view was cleared programmatically' do
        let(:payload) do
          {
            'type' => 'view_closed',
            'view' => { 'callback_id' => 'test_modal' },
            'is_cleared' => true
          }
        end

        it 'returns true' do
          expect(handler.is_cleared?).to be true
        end
      end
    end

    describe '#user_id' do
      it 'returns the user id' do
        expect(handler.user_id).to eq('U12345')
      end
    end
  end
end
