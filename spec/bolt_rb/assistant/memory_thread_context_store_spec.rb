# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Assistant::MemoryThreadContextStore do
  subject(:store) { described_class.new }

  it 'returns nil for an unknown thread' do
    expect(store.get(channel_id: 'D1', thread_ts: '1.0')).to be_nil
  end

  it 'returns the saved context for a thread' do
    store.save(channel_id: 'D1', thread_ts: '1.0', context: { 'channel_id' => 'C1' })
    expect(store.get(channel_id: 'D1', thread_ts: '1.0')).to eq({ 'channel_id' => 'C1' })
  end

  it 'overwrites the context on a second save' do
    store.save(channel_id: 'D1', thread_ts: '1.0', context: { 'channel_id' => 'C1' })
    store.save(channel_id: 'D1', thread_ts: '1.0', context: { 'channel_id' => 'C2' })
    expect(store.get(channel_id: 'D1', thread_ts: '1.0')).to eq({ 'channel_id' => 'C2' })
  end

  it 'keeps threads separate' do
    store.save(channel_id: 'D1', thread_ts: '1.0', context: { 'channel_id' => 'C1' })
    store.save(channel_id: 'D1', thread_ts: '2.0', context: { 'channel_id' => 'C2' })
    expect(store.get(channel_id: 'D1', thread_ts: '1.0')).to eq({ 'channel_id' => 'C1' })
  end
end
