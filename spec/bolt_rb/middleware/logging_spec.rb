# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Middleware::Logging do
  let(:middleware) { described_class.new }
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { proc { } }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }

  describe '#call' do
    let(:payload) { { 'event' => { 'type' => 'message' } } }

    it 'logs processing and completion' do
      expect(BoltRb.logger).to receive(:info).with('[BoltRb] Processing event:message')
      expect(BoltRb.logger).to receive(:info).with(/\[BoltRb\] Completed event:message in \d+\.?\d*ms/)

      middleware.call(context) { }
    end

    it 'yields to the block' do
      allow(BoltRb.logger).to receive(:info)
      expect { |b| middleware.call(context, &b) }.to yield_control
    end
  end

  describe '#determine_event_type' do
    subject(:event_type) { middleware.send(:determine_event_type, payload) }

    context 'with an event payload' do
      let(:payload) { { 'event' => { 'type' => 'message' } } }

      it { is_expected.to eq('event:message') }
    end

    context 'with an app_mention event' do
      let(:payload) { { 'event' => { 'type' => 'app_mention' } } }

      it { is_expected.to eq('event:app_mention') }
    end

    context 'with a slash command' do
      let(:payload) { { 'command' => '/deploy' } }

      it { is_expected.to eq('command:/deploy') }
    end

    context 'with block_actions' do
      let(:payload) do
        {
          'type'    => 'block_actions',
          'actions' => [{ 'action_id' => 'approve_button' }]
        }
      end

      it { is_expected.to eq('action:approve_button') }
    end

    context 'with multiple block_actions' do
      let(:payload) do
        {
          'type'    => 'block_actions',
          'actions' => [
            { 'action_id' => 'approve_button' },
            { 'action_id' => 'reject_button' }
          ]
        }
      end

      it { is_expected.to eq('action:approve_button,reject_button') }
    end

    context 'with a shortcut' do
      let(:payload) { { 'type' => 'shortcut', 'callback_id' => 'create_ticket' } }

      it { is_expected.to eq('shortcut:create_ticket') }
    end

    context 'with a message_action' do
      let(:payload) { { 'type' => 'message_action', 'callback_id' => 'flag_message' } }

      it { is_expected.to eq('shortcut:flag_message') }
    end

    context 'with view_submission' do
      let(:payload) do
        {
          'type' => 'view_submission',
          'view' => { 'callback_id' => 'create_ticket_modal' }
        }
      end

      it { is_expected.to eq('view_submission:create_ticket_modal') }
    end

    context 'with view_closed' do
      let(:payload) do
        {
          'type' => 'view_closed',
          'view' => { 'callback_id' => 'settings_modal' }
        }
      end

      it { is_expected.to eq('view_closed:settings_modal') }
    end

    context 'with an unknown payload type' do
      let(:payload) { { 'type' => 'something_else' } }

      it { is_expected.to eq('unknown') }
    end

    context 'with an empty payload' do
      let(:payload) { {} }

      it { is_expected.to eq('unknown') }
    end
  end
end
