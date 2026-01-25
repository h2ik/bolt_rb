# frozen_string_literal: true

require_relative 'bolt_rb/version'
require_relative 'bolt_rb/middleware/logging'
require_relative 'bolt_rb/configuration'
require_relative 'bolt_rb/context'
require_relative 'bolt_rb/handlers/base'
require_relative 'bolt_rb/handlers/event_handler'
require_relative 'bolt_rb/handlers/command_handler'
require_relative 'bolt_rb/handlers/action_handler'

module BoltRb
  class Error < StandardError; end

  class << self
    # Returns the current configuration instance
    #
    # @return [Configuration] The memoized configuration instance
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the configuration for block-style configuration
    #
    # @yield [Configuration] The configuration instance
    # @example
    #   BoltRb.configure do |config|
    #     config.bot_token = 'xoxb-...'
    #   end
    def configure
      yield(configuration)
    end

    # Resets the configuration to a fresh instance
    # Useful for testing or reconfiguration scenarios
    #
    # @return [Configuration] The new configuration instance
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience accessor for the logger
    #
    # @return [Logger] The configured logger instance
    def logger
      configuration.logger
    end
  end
end
