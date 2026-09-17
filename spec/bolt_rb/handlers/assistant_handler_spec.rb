# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::AssistantHandler do
  let(:handler_class) do
    Class.new(described_class) do
      def thread_started; end
      def user_message; end
    end
  end

  describe '.matches?' do
    it 'matches assistant_thread_started events' do
      payload = { 'event' => { 'type' => 'assistant_thread_started' } }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'matches assistant_thread_context_changed events' do
      payload = { 'event' => { 'type' => 'assistant_thread_context_changed' } }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'matches threaded direct messages from users' do
      payload = {
        'event' => {
          'type' => 'message',
          'channel_type' => 'im',
          'thread_ts' => '1234.5678',
          'text' => 'hi'
        }
      }
      expect(handler_class.matches?(payload)).to be true
    end

    it 'does not match direct messages outside a thread' do
      payload = { 'event' => { 'type' => 'message', 'channel_type' => 'im', 'text' => 'hi' } }
      expect(handler_class.matches?(payload)).to be false
    end

    it 'does not match threaded messages in channels' do
      payload = {
        'event' => { 'type' => 'message', 'channel_type' => 'channel', 'thread_ts' => '1234.5678' }
      }
      expect(handler_class.matches?(payload)).to be false
    end

    it 'does not match bot messages' do
      payload = {
        'event' => {
          'type' => 'message',
          'channel_type' => 'im',
          'thread_ts' => '1234.5678',
          'bot_id' => 'B123'
        }
      }
      expect(handler_class.matches?(payload)).to be false
    end

    it 'does not match message subtypes such as message_changed' do
      payload = {
        'event' => {
          'type' => 'message',
          'channel_type' => 'im',
          'thread_ts' => '1234.5678',
          'subtype' => 'message_changed'
        }
      }
      expect(handler_class.matches?(payload)).to be false
    end

    it 'does not match unrelated events' do
      payload = { 'event' => { 'type' => 'app_mention' } }
      expect(handler_class.matches?(payload)).to be false
    end

    it 'does not match payloads without an event' do
      expect(handler_class.matches?({ 'command' => '/x' })).to be false
    end
  end

  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
  subject(:handler) { handler_class.new(context) }

  let(:thread_started_payload) do
    {
      'event' => {
        'type' => 'assistant_thread_started',
        'assistant_thread' => {
          'user_id' => 'U111',
          'channel_id' => 'D222',
          'thread_ts' => '1700000000.000100',
          'context' => { 'channel_id' => 'C333', 'team_id' => 'T444' }
        }
      }
    }
  end

  let(:context_changed_payload) do
    {
      'event' => {
        'type' => 'assistant_thread_context_changed',
        'assistant_thread' => {
          'user_id' => 'U111',
          'channel_id' => 'D222',
          'thread_ts' => '1700000000.000100',
          'context' => { 'channel_id' => 'C999', 'team_id' => 'T444' }
        }
      }
    }
  end

  let(:user_message_payload) do
    {
      'event' => {
        'type' => 'message',
        'channel_type' => 'im',
        'user' => 'U111',
        'channel' => 'D222',
        'thread_ts' => '1700000000.000100',
        'ts' => '1700000000.000200',
        'text' => 'what is up'
      }
    }
  end

  describe 'accessors' do
    context 'for an assistant_thread_started event' do
      let(:payload) { thread_started_payload }

      it 'reads channel from the assistant_thread' do
        expect(handler.channel).to eq('D222')
      end

      it 'reads thread_ts from the assistant_thread' do
        expect(handler.thread_ts).to eq('1700000000.000100')
      end

      it 'reads user from the assistant_thread' do
        expect(handler.user).to eq('U111')
      end

      it 'reads thread_context from the assistant_thread' do
        expect(handler.thread_context).to eq({ 'channel_id' => 'C333', 'team_id' => 'T444' })
      end

      it 'returns nil text' do
        expect(handler.text).to be_nil
      end
    end

    context 'for a user message event' do
      let(:payload) { user_message_payload }

      it 'reads channel from the message' do
        expect(handler.channel).to eq('D222')
      end

      it 'reads thread_ts from the message' do
        expect(handler.thread_ts).to eq('1700000000.000100')
      end

      it 'reads user from the message' do
        expect(handler.user).to eq('U111')
      end

      it 'reads text from the message' do
        expect(handler.text).to eq('what is up')
      end
    end
  end

  describe '#call dispatch' do
    let(:handler_class) do
      Class.new(described_class) do
        attr_reader :called

        def thread_started
          @called = :thread_started
        end

        def context_changed
          @called = :context_changed
        end

        def user_message
          @called = :user_message
        end
      end
    end

    context 'for assistant_thread_started' do
      let(:payload) { thread_started_payload }

      it 'calls #thread_started' do
        handler.call
        expect(handler.called).to eq(:thread_started)
      end
    end

    context 'for assistant_thread_context_changed' do
      let(:payload) { context_changed_payload }

      it 'calls #context_changed' do
        handler.call
        expect(handler.called).to eq(:context_changed)
      end
    end

    context 'for a user message' do
      let(:payload) { user_message_payload }

      it 'calls #user_message' do
        handler.call
        expect(handler.called).to eq(:user_message)
      end
    end
  end

  describe 'API helpers' do
    let(:payload) { user_message_payload }

    describe '#set_status' do
      it 'calls assistant.threads.setStatus with channel and thread' do
        expect(client).to receive(:assistant_threads_setStatus).with({
          channel_id: 'D222', thread_ts: '1700000000.000100', status: 'is thinking...'
        })
        handler.set_status('is thinking...')
      end
    end

    describe '#set_title' do
      it 'calls assistant.threads.setTitle with channel and thread' do
        expect(client).to receive(:assistant_threads_setTitle).with({
          channel_id: 'D222', thread_ts: '1700000000.000100', title: 'Deploy help'
        })
        handler.set_title('Deploy help')
      end
    end

    describe '#set_suggested_prompts' do
      it 'expands plain strings into title and message pairs' do
        expect(client).to receive(:assistant_threads_setSuggestedPrompts).with({
          channel_id: 'D222',
          thread_ts: '1700000000.000100',
          prompts: [
            { title: 'Summarize', message: 'Summarize' },
            { title: 'Help', message: 'Help' }
          ]
        })
        handler.set_suggested_prompts(%w[Summarize Help])
      end

      it 'passes hash prompts through unchanged' do
        prompt = { title: 'Summarize', message: 'Summarize this channel' }
        expect(client).to receive(:assistant_threads_setSuggestedPrompts).with({
          channel_id: 'D222', thread_ts: '1700000000.000100', prompts: [prompt]
        })
        handler.set_suggested_prompts([prompt])
      end

      it 'includes a title when given' do
        expect(client).to receive(:assistant_threads_setSuggestedPrompts).with({
          channel_id: 'D222',
          thread_ts: '1700000000.000100',
          prompts: [{ title: 'Help', message: 'Help' }],
          title: 'Try one of these'
        })
        handler.set_suggested_prompts(['Help'], title: 'Try one of these')
      end
    end

    describe '#say' do
      it 'posts a string into the assistant thread' do
        expect(client).to receive(:chat_postMessage).with({
          text: 'hello', channel: 'D222', thread_ts: '1700000000.000100'
        })
        handler.say('hello')
      end

      it 'posts a hash into the assistant thread' do
        expect(client).to receive(:chat_postMessage).with({
          blocks: [], channel: 'D222', thread_ts: '1700000000.000100'
        })
        handler.say(blocks: [])
      end
    end

    context 'for an assistant_thread_started event' do
      let(:payload) { thread_started_payload }

      it 'targets the assistant thread from the event' do
        expect(client).to receive(:assistant_threads_setStatus).with({
          channel_id: 'D222', thread_ts: '1700000000.000100', status: 'x'
        })
        handler.set_status('x')
      end
    end
  end

  describe 'thread context persistence' do
    let(:store) { BoltRb::Assistant::MemoryThreadContextStore.new }

    before do
      BoltRb.reset_configuration!
      BoltRb.configuration.assistant_thread_context_store = store
    end

    after { BoltRb.reset_configuration! }

    def build(payload)
      handler_class.new(BoltRb::Context.new(payload: payload, client: client, ack: ack_fn))
    end

    it 'saves the context when a thread starts' do
      build(thread_started_payload).call
      expect(store.get(channel_id: 'D222', thread_ts: '1700000000.000100'))
        .to eq({ 'channel_id' => 'C333', 'team_id' => 'T444' })
    end

    it 'updates the context when the context changes' do
      build(thread_started_payload).call
      build(context_changed_payload).call
      expect(store.get(channel_id: 'D222', thread_ts: '1700000000.000100'))
        .to eq({ 'channel_id' => 'C999', 'team_id' => 'T444' })
    end

    it 'exposes the saved context to user messages' do
      build(thread_started_payload).call
      expect(build(user_message_payload).thread_context)
        .to eq({ 'channel_id' => 'C333', 'team_id' => 'T444' })
    end

    it 'returns nil context for user messages in unknown threads' do
      expect(build(user_message_payload).thread_context).to be_nil
    end

    it 'lets a handler save context by hand' do
      handler = build(user_message_payload)
      handler.save_thread_context({ 'channel_id' => 'C777' })
      expect(store.get(channel_id: 'D222', thread_ts: '1700000000.000100'))
        .to eq({ 'channel_id' => 'C777' })
    end
  end

  describe 'default hooks' do
    let(:handler_class) { Class.new(described_class) }

    it 'raises NotImplementedError for thread_started' do
      handler = handler_class.new(
        BoltRb::Context.new(payload: thread_started_payload, client: client, ack: ack_fn)
      )
      expect { handler.call }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for user_message' do
      handler = handler_class.new(
        BoltRb::Context.new(payload: user_message_payload, client: client, ack: ack_fn)
      )
      expect { handler.call }.to raise_error(NotImplementedError)
    end

    it 'does not raise for context_changed' do
      handler = handler_class.new(
        BoltRb::Context.new(payload: context_changed_payload, client: client, ack: ack_fn)
      )
      expect { handler.call }.not_to raise_error
    end
  end
end
