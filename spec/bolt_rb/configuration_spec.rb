# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoltRb::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default handler_paths' do
      expect(config.handler_paths).to eq(['app/slack_handlers'])
    end

    it 'sets default logger' do
      expect(config.logger).to be_a(Logger)
    end

    it 'initializes empty middleware array with logging' do
      expect(config.middleware).to eq([BoltRb::Middleware::Logging])
    end
  end

  describe 'accessors' do
    it 'allows setting bot_token' do
      config.bot_token = 'xoxb-test'
      expect(config.bot_token).to eq('xoxb-test')
    end

    it 'allows setting app_token' do
      config.app_token = 'xapp-test'
      expect(config.app_token).to eq('xapp-test')
    end

    it 'allows setting error_handler' do
      handler = ->(e, event) { puts e }
      config.error_handler = handler
      expect(config.error_handler).to eq(handler)
    end
  end

  describe '#use' do
    it 'adds middleware to the stack' do
      middleware_class = Class.new
      config.use(middleware_class)
      expect(config.middleware).to include(middleware_class)
    end
  end
end

RSpec.describe BoltRb do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(BoltRb.configuration).to be_a(BoltRb::Configuration)
    end

    it 'memoizes the configuration' do
      expect(BoltRb.configuration).to be(BoltRb.configuration)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      BoltRb.configure do |config|
        expect(config).to be(BoltRb.configuration)
      end
    end
  end

  describe '.reset_configuration!' do
    it 'resets to a new configuration' do
      old_config = BoltRb.configuration
      BoltRb.reset_configuration!
      expect(BoltRb.configuration).not_to be(old_config)
    end
  end
end
