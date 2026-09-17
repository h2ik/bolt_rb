# frozen_string_literal: true

require 'logger'

module BoltRb
  # Configuration class for BoltRb applications
  #
  # Holds all settings including tokens, handler paths, logger,
  # middleware stack, and error handling configuration.
  #
  # @example Basic configuration
  #   BoltRb.configure do |config|
  #     config.bot_token = ENV['SLACK_BOT_TOKEN']
  #     config.app_token = ENV['SLACK_APP_TOKEN']
  #     config.signing_secret = ENV['SLACK_SIGNING_SECRET']
  #   end
  #
  # @example Adding custom middleware
  #   BoltRb.configure do |config|
  #     config.use MyCustomMiddleware
  #   end
  #
  class Configuration
    attr_accessor :bot_token, :app_token, :signing_secret,
                  :handler_paths, :logger, :error_handler

    # @return [Integer] Number of threads that run handlers. Default 5.
    attr_accessor :worker_threads

    attr_writer :assistant_thread_context_store

    attr_reader :middleware

    def initialize
      @handler_paths = ['app/slack_handlers']
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @middleware = [BoltRb::Middleware::Logging]
      @worker_threads = 5
    end

    # Return the store for assistant thread context
    #
    # Defaults to an in-process memory store. Any object that responds to
    # `get(channel_id:, thread_ts:)` and `save(channel_id:, thread_ts:, context:)`
    # can replace it.
    #
    # @return [Object] The thread context store
    def assistant_thread_context_store
      @assistant_thread_context_store ||= BoltRb::Assistant::MemoryThreadContextStore.new
    end

    # Add middleware to the stack
    #
    # @param middleware_class [Class] The middleware class to add
    # @return [Array<Class>] The updated middleware stack
    def use(middleware_class)
      @middleware << middleware_class
    end
  end
end
