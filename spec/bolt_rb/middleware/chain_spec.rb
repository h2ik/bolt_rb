# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Middleware::Chain do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:payload) { { 'event' => { 'type' => 'message' } } }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }

  describe '#call' do
    it 'calls the block when no middleware' do
      called = false
      described_class.new([]).call(context) { called = true }
      expect(called).to be true
    end

    it 'runs middleware in order' do
      order = []

      middleware1 = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          order << :first_before
          block.call
          order << :first_after
        end
      end

      middleware2 = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          order << :second_before
          block.call
          order << :second_after
        end
      end

      described_class.new([middleware1, middleware2]).call(context) do
        order << :handler
      end

      expect(order).to eq([:first_before, :second_before, :handler, :second_after, :first_after])
    end

    it 'stops chain when middleware does not yield' do
      blocking_middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          # Don't call block - stops chain
        end
      end

      called = false
      described_class.new([blocking_middleware]).call(context) { called = true }
      expect(called).to be false
    end

    it 'passes context to middleware' do
      received_context = nil

      middleware = Class.new(BoltRb::Middleware::Base) do
        define_method(:call) do |ctx, &block|
          received_context = ctx
          block.call
        end
      end

      described_class.new([middleware]).call(context) {}
      expect(received_context).to eq(context)
    end
  end
end

RSpec.describe BoltRb::Middleware::Base do
  describe '#call' do
    it 'yields by default' do
      called = false
      described_class.new.call(nil) { called = true }
      expect(called).to be true
    end
  end
end

RSpec.describe BoltRb::Middleware::Logging do
  let(:client) { instance_double(Slack::Web::Client) }
  let(:ack_fn) { ->(_) {} }
  let(:payload) { { 'event' => { 'type' => 'message' } } }
  let(:context) { BoltRb::Context.new(payload: payload, client: client, ack: ack_fn) }
  let(:logger) { instance_double(Logger, info: nil) }

  before do
    allow(BoltRb).to receive(:logger).and_return(logger)
  end

  describe '#call' do
    it 'logs the event type' do
      described_class.new.call(context) {}
      expect(logger).to have_received(:info).at_least(:once)
    end

    it 'yields to next middleware' do
      called = false
      described_class.new.call(context) { called = true }
      expect(called).to be true
    end
  end
end
