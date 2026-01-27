# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::ViewSubmissionHandler do
  describe '.view' do
    let(:handler_class) do
      Class.new(described_class) do
        view 'create_ticket_modal'
      end
    end

    it 'sets matcher_config type to :view_submission' do
      expect(handler_class.matcher_config[:type]).to eq(:view_submission)
    end

    it 'sets the callback_id' do
      expect(handler_class.matcher_config[:callback_id]).to eq('create_ticket_modal')
    end

    context 'with regex' do
      let(:handler_class) do
        Class.new(described_class) do
          view /^form_step_/
        end
      end

      it 'stores regex pattern' do
        expect(handler_class.matcher_config[:callback_id]).to eq(/^form_step_/)
      end
    end
  end

  describe '.matches?' do
    context 'string callback_id' do
      let(:handler_class) do
        Class.new(described_class) do
          view 'create_ticket_modal'
        end
      end

      it 'matches when callback_id matches' do
        payload = {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'create_ticket_modal' }
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match wrong callback_id' do
        payload = {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'other_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end

      it 'does not match wrong type' do
        payload = {
          'type' => 'block_actions',
          'view' => { 'callback_id' => 'create_ticket_modal' }
        }
        expect(handler_class.matches?(payload)).to be false
      end
    end

    context 'regex callback_id' do
      let(:handler_class) do
        Class.new(described_class) do
          view /^form_step_/
        end
      end

      it 'matches when pattern matches' do
        payload = {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'form_step_3' }
        }
        expect(handler_class.matches?(payload)).to be true
      end

      it 'does not match when pattern does not match' do
        payload = {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'other_form' }
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
        'type' => 'view_submission',
        'user' => { 'id' => 'U123' },
        'view' => {
          'callback_id' => 'create_ticket_modal',
          'private_metadata' => 'ticket_123',
          'hash' => 'view_hash_abc',
          'state' => {
            'values' => {
              'title_block' => {
                'title_input' => { 'type' => 'plain_text_input', 'value' => 'My Ticket' }
              },
              'priority_block' => {
                'priority_select' => {
                  'type' => 'static_select',
                  'selected_option' => { 'value' => 'high' }
                }
              }
            }
          }
        },
        'response_urls' => [{ 'block_id' => 'actions', 'response_url' => 'https://hooks.slack.com/xxx' }]
      }
    end
    let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
    let(:handler_class) do
      Class.new(described_class) do
        view 'create_ticket_modal'

        def handle
          # no-op
        end
      end
    end

    subject(:handler) { handler_class.new(context) }

    describe '#view' do
      it 'returns the view object' do
        expect(handler.view).to eq(payload['view'])
      end
    end

    describe '#callback_id' do
      it 'returns the callback_id' do
        expect(handler.callback_id).to eq('create_ticket_modal')
      end
    end

    describe '#private_metadata' do
      it 'returns the private_metadata' do
        expect(handler.private_metadata).to eq('ticket_123')
      end
    end

    describe '#values' do
      it 'returns the form values' do
        expect(handler.values).to eq(payload.dig('view', 'state', 'values'))
      end
    end

    describe '#user_id' do
      it 'returns the user id' do
        expect(handler.user_id).to eq('U123')
      end
    end

    describe '#response_urls' do
      it 'returns the response_urls array' do
        expect(handler.response_urls).to eq(payload['response_urls'])
      end
    end

    describe '#view_hash' do
      it 'returns the view hash' do
        expect(handler.view_hash).to eq('view_hash_abc')
      end
    end
  end
end
