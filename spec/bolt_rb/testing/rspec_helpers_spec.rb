# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Testing::RSpecHelpers do
  include described_class

  describe '#mock_slack_client' do
    subject(:client) { mock_slack_client }

    it 'stubs chat_postMessage' do
      expect(client.chat_postMessage(channel: 'C1', text: 'x')['ok']).to be true
    end

    it 'stubs assistant_threads_setStatus' do
      expect(client.assistant_threads_setStatus(channel_id: 'D1', thread_ts: '1.0', status: 'x')['ok'])
        .to be true
    end

    it 'stubs assistant_threads_setTitle' do
      expect(client.assistant_threads_setTitle(channel_id: 'D1', thread_ts: '1.0', title: 'x')['ok'])
        .to be true
    end

    it 'stubs assistant_threads_setSuggestedPrompts' do
      response = client.assistant_threads_setSuggestedPrompts(channel_id: 'D1', thread_ts: '1.0', prompts: [])
      expect(response['ok']).to be true
    end
  end

  describe '#build_context' do
    it 'wraps a payload in a Context with a mock client' do
      ctx = build_context(payload.message(text: 'hi'))
      expect(ctx).to be_a(BoltRb::Context)
      expect(ctx.text).to eq('hi')
    end
  end
end
