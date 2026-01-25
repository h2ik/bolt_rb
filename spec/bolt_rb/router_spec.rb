# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Router do
  subject(:router) { described_class.new }

  let(:message_handler) do
    Class.new(BoltRb::EventHandler) do
      listen_to :message
      def handle; end
    end
  end

  let(:hello_handler) do
    Class.new(BoltRb::EventHandler) do
      listen_to :message, pattern: /hello/i
      def handle; end
    end
  end

  let(:deploy_command) do
    Class.new(BoltRb::CommandHandler) do
      command '/deploy'
      def handle; end
    end
  end

  let(:approve_action) do
    Class.new(BoltRb::ActionHandler) do
      action 'approve'
      def handle; end
    end
  end

  let(:create_shortcut) do
    Class.new(BoltRb::ShortcutHandler) do
      shortcut 'create_ticket'
      def handle; end
    end
  end

  describe '#register' do
    it 'registers event handlers' do
      router.register(message_handler)
      expect(router.handler_count).to eq(1)
    end

    it 'registers command handlers' do
      router.register(deploy_command)
      expect(router.handler_count).to eq(1)
    end

    it 'registers action handlers' do
      router.register(approve_action)
      expect(router.handler_count).to eq(1)
    end

    it 'registers shortcut handlers' do
      router.register(create_shortcut)
      expect(router.handler_count).to eq(1)
    end
  end

  describe '#route' do
    before do
      router.register(message_handler)
      router.register(hello_handler)
      router.register(deploy_command)
      router.register(approve_action)
      router.register(create_shortcut)
    end

    context 'events' do
      it 'returns matching event handlers' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'hello world' } }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(message_handler, hello_handler)
      end

      it 'filters by pattern' do
        payload = { 'event' => { 'type' => 'message', 'text' => 'goodbye' } }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(message_handler)
      end
    end

    context 'commands' do
      it 'returns matching command handlers' do
        payload = { 'command' => '/deploy', 'text' => 'production' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(deploy_command)
      end

      it 'returns empty for non-matching commands' do
        payload = { 'command' => '/rollback' }
        handlers = router.route(payload)
        expect(handlers).to be_empty
      end
    end

    context 'actions' do
      it 'returns matching action handlers' do
        payload = {
          'type' => 'block_actions',
          'actions' => [{ 'action_id' => 'approve' }]
        }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(approve_action)
      end
    end

    context 'shortcuts' do
      it 'returns matching shortcut handlers' do
        payload = { 'type' => 'shortcut', 'callback_id' => 'create_ticket' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(create_shortcut)
      end

      it 'returns matching message shortcut handlers' do
        payload = { 'type' => 'message_action', 'callback_id' => 'create_ticket' }
        handlers = router.route(payload)
        expect(handlers).to contain_exactly(create_shortcut)
      end
    end
  end

  describe '#clear' do
    it 'removes all registered handlers' do
      router.register(message_handler)
      router.clear
      expect(router.handler_count).to eq(0)
    end
  end
end
