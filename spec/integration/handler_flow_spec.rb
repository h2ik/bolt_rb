# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Handler Integration', type: :integration do
  include BoltRb::Testing::RSpecHelpers

  before do
    BoltRb.reset_configuration!
    BoltRb.reset_router!
  end

  describe 'EventHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::EventHandler) do
        listen_to :message, pattern: /hello/i

        def handle
          say "Hi <@#{user}>!"
        end
      end
    end

    it 'handles matching events' do
      BoltRb.router.register(handler_class)

      context = build_context(payload.message(text: 'hello world', user: 'U999'))
      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Hi <@U999>!')
      )
    end

    it 'does not match non-matching events' do
      expect(handler_class.matches?(payload.message(text: 'goodbye'))).to be false
    end

    it 'matches events with correct pattern' do
      expect(handler_class.matches?(payload.message(text: 'Hello there!'))).to be true
    end
  end

  describe 'CommandHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::CommandHandler) do
        command '/greet'

        def handle
          ack "Greeting #{command_text}..."
          say "Hello, #{command_text}!"
        end
      end
    end

    it 'handles matching commands' do
      BoltRb.router.register(handler_class)

      acked_with = nil
      ack_fn = ->(response) { acked_with = response }
      context = build_context(
        payload.command(command: '/greet', text: 'world'),
        ack: ack_fn
      )

      handler_class.new(context).call

      expect(acked_with).to eq('Greeting world...')
      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Hello, world!')
      )
    end

    it 'does not match other commands' do
      expect(handler_class.matches?(payload.command(command: '/other'))).to be false
    end

    it 'matches the correct command' do
      expect(handler_class.matches?(payload.command(command: '/greet'))).to be true
    end
  end

  describe 'ActionHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::ActionHandler) do
        action 'confirm_button'

        def handle
          ack
          say "Confirmed: #{action_value}"
        end
      end
    end

    it 'handles matching actions' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.action(action_id: 'confirm_button', value: 'item_123')
      )

      handler_class.new(context).call

      expect(context).to be_acked
      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Confirmed: item_123')
      )
    end

    it 'does not match other action IDs' do
      expect(handler_class.matches?(payload.action(action_id: 'other_button'))).to be false
    end

    it 'matches the correct action ID' do
      expect(handler_class.matches?(payload.action(action_id: 'confirm_button'))).to be true
    end
  end

  describe 'ShortcutHandler flow' do
    let(:handler_class) do
      Class.new(BoltRb::ShortcutHandler) do
        shortcut 'create_task'

        def handle
          ack
          client.views_open(
            trigger_id: trigger_id,
            view: { type: 'modal', title: { type: 'plain_text', text: 'New Task' } }
          )
        end
      end
    end

    it 'handles matching shortcuts' do
      BoltRb.router.register(handler_class)

      context = build_context(payload.shortcut(callback_id: 'create_task'))
      handler_class.new(context).call

      expect(context).to be_acked
      expect(context.client).to have_received(:views_open).with(
        hash_including(view: hash_including(type: 'modal'))
      )
    end

    it 'does not match other callback IDs' do
      expect(handler_class.matches?(payload.shortcut(callback_id: 'other_shortcut'))).to be false
    end

    it 'matches the correct callback ID' do
      expect(handler_class.matches?(payload.shortcut(callback_id: 'create_task'))).to be true
    end
  end

  describe 'Middleware integration' do
    let(:admin_middleware) do
      Class.new(BoltRb::Middleware::Base) do
        def call(context)
          if context.user == 'UADMIN'
            yield if block_given?
          else
            context.say 'Not authorized'
          end
        end
      end
    end

    let(:handler_class) do
      admin_mw = admin_middleware
      Class.new(BoltRb::CommandHandler) do
        command '/admin'
        use admin_mw

        def handle
          ack
          say 'Admin action executed'
        end
      end
    end

    it 'allows authorized users' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.command(command: '/admin', user: 'UADMIN')
      )

      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Admin action executed')
      )
    end

    it 'blocks unauthorized users' do
      BoltRb.router.register(handler_class)

      context = build_context(
        payload.command(command: '/admin', user: 'URANDO')
      )

      handler_class.new(context).call

      expect(context.client).to have_received(:chat_postMessage).with(
        hash_including(text: 'Not authorized')
      )
      expect(context.client).not_to have_received(:chat_postMessage).with(
        hash_including(text: 'Admin action executed')
      )
    end

    it 'executes middleware in order' do
      execution_order = []

      first_middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |context, &block|
          execution_order << :first_before
          block.call if block
          execution_order << :first_after
        end
      end

      second_middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |context, &block|
          execution_order << :second_before
          block.call if block
          execution_order << :second_after
        end
      end

      test_handler = Class.new(BoltRb::CommandHandler) do
        command '/test'
        use first_middleware
        use second_middleware

        define_method(:handle) do
          execution_order << :handler
          ack
        end
      end

      context = build_context(payload.command(command: '/test'))
      test_handler.new(context).call

      expect(execution_order).to eq(%i[first_before second_before handler second_after first_after])
    end
  end

  describe 'Router integration' do
    it 'routes to multiple matching handlers' do
      all_messages_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        define_method(:handle) { say 'Logging message' }
      end

      hello_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message, pattern: /hello/i
        define_method(:handle) { say 'Hello!' }
      end

      goodbye_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message, pattern: /goodbye/i
        define_method(:handle) { say 'Goodbye!' }
      end

      BoltRb.router.register(all_messages_handler)
      BoltRb.router.register(hello_handler)
      BoltRb.router.register(goodbye_handler)

      message_payload = payload.message(text: 'Hello, world!')
      matching_handlers = BoltRb.router.route(message_payload)

      expect(matching_handlers).to contain_exactly(all_messages_handler, hello_handler)
      expect(matching_handlers).not_to include(goodbye_handler)
    end

    it 'routes commands to correct handlers' do
      deploy_handler = Class.new(BoltRb::CommandHandler) do
        command '/deploy'
        define_method(:handle) { ack }
      end

      status_handler = Class.new(BoltRb::CommandHandler) do
        command '/status'
        define_method(:handle) { ack }
      end

      BoltRb.router.register(deploy_handler)
      BoltRb.router.register(status_handler)

      deploy_payload = payload.command(command: '/deploy')
      status_payload = payload.command(command: '/status')

      expect(BoltRb.router.route(deploy_payload)).to eq([deploy_handler])
      expect(BoltRb.router.route(status_payload)).to eq([status_handler])
    end
  end

  describe 'Error handling' do
    it 'raises NotImplementedError for unimplemented handlers' do
      incomplete_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message
        # intentionally not implementing #handle
      end

      context = build_context(payload.message(text: 'test'))

      expect do
        incomplete_handler.new(context).call
      end.to raise_error(NotImplementedError, /must implement #handle/)
    end
  end

  describe 'Context propagation' do
    it 'provides access to payload data in handlers' do
      captured_data = {}

      data_capture_handler = Class.new(BoltRb::EventHandler) do
        listen_to :message

        define_method(:handle) do
          captured_data[:user] = user
          captured_data[:channel] = channel
          captured_data[:text] = text
          captured_data[:ts] = ts
        end
      end

      context = build_context(
        payload.message(text: 'test message', user: 'UTEST', channel: 'CTEST')
      )

      data_capture_handler.new(context).call

      expect(captured_data[:user]).to eq('UTEST')
      expect(captured_data[:channel]).to eq('CTEST')
      expect(captured_data[:text]).to eq('test message')
      expect(captured_data[:ts]).not_to be_nil
    end
  end
end
