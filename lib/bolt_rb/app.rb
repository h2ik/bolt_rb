# frozen_string_literal: true

require 'slack-ruby-client'

module BoltRb
  # Main application class for running a Bolt app with Socket Mode
  #
  # This class initializes the Slack clients, loads handlers, and processes
  # incoming events through the middleware chain and router.
  #
  # @example Basic usage
  #   BoltRb.configure do |config|
  #     config.bot_token = ENV['SLACK_BOT_TOKEN']
  #     config.app_token = ENV['SLACK_APP_TOKEN']
  #   end
  #
  #   app = BoltRb::App.new
  #   app.start
  #
  # @example With custom handler paths
  #   BoltRb.configure do |config|
  #     config.bot_token = ENV['SLACK_BOT_TOKEN']
  #     config.app_token = ENV['SLACK_APP_TOKEN']
  #     config.handler_paths = ['lib/handlers']
  #   end
  #
  #   app = BoltRb::App.new
  #   app.start
  class App
    # @return [Slack::Web::Client] The Slack Web API client
    attr_reader :client

    # @return [Router] The router instance for dispatching events
    attr_reader :router

    # @return [Configuration] The configuration instance
    attr_reader :config

    # @return [SocketMode::Client] The Socket Mode client instance
    attr_reader :socket_client

    # Creates a new App instance
    #
    # Initializes the Slack Web API client for making API calls
    # and the Socket Mode client for receiving events.
    def initialize
      @config = BoltRb.configuration
      @router = BoltRb.router
      @client = Slack::Web::Client.new(token: config.bot_token)

      setup_socket_client
    end

    # Starts the Socket Mode connection
    #
    # Loads all handlers from configured paths and connects to Slack
    # via Socket Mode to start receiving events.
    #
    # @return [void]
    def start
      load_handlers
      BoltRb.logger.info '[BoltRb] Starting app...'
      @socket_client.start
    end

    # Stops the Socket Mode connection
    #
    # Gracefully disconnects from Slack.
    #
    # @return [void]
    def stop
      BoltRb.logger.info '[BoltRb] Stopping app...'
      @socket_client.stop
    end

    # Requests a stop - safe to call from trap context
    #
    # Use this in signal handlers instead of stop to avoid
    # ThreadError from calling methods that use mutexes.
    #
    # @return [void]
    def request_stop
      @socket_client.request_stop
    end

    # @return [Boolean] Whether the app is currently running
    def running?
      @socket_client.running?
    end

    # Processes an incoming event payload
    #
    # Routes the event to matching handlers and executes them through
    # the middleware chain. Errors in individual handlers are caught
    # and passed to the configured error handler without stopping
    # other handlers from executing.
    #
    # @param payload [Hash] The incoming Slack event payload
    # @return [void]
    def process_event(payload)
      handlers = router.route(payload)
      return if handlers.empty?

      context = build_context(payload)

      Middleware::Chain.new(config.middleware).call(context) do
        handlers.each do |handler_class|
          execute_handler(handler_class, context)
        end
      end
    end

    private

    # Sets up the Socket Mode client with event handling
    #
    # @return [void]
    def setup_socket_client
      @socket_client = SocketMode::Client.new(
        app_token: config.app_token,
        logger: BoltRb.logger
      )

      @socket_client.on_message do |data|
        handle_socket_event(data)
      end
    end

    # Handles incoming Socket Mode events
    #
    # Extracts the payload from the Socket Mode envelope and routes it
    # to the appropriate handlers.
    #
    # @param data [Hash] The Socket Mode envelope data
    # @return [void]
    def handle_socket_event(data)
      payload = extract_payload(data)
      process_event(payload) if payload
    rescue StandardError => e
      BoltRb.logger.error "[BoltRb] Error handling socket event: #{e.message}"
      BoltRb.logger.error e.backtrace.first(5).join("\n")
    end

    # Extracts the event payload from a Socket Mode envelope
    #
    # @param data [Hash] The Socket Mode envelope
    # @return [Hash, nil] The extracted payload or nil if not processable
    def extract_payload(data)
      case data['type']
      when 'events_api'
        data['payload']
      when 'interactive', 'slash_commands', 'block_actions', 'view_submission', 'view_closed', 'shortcut'
        data['payload']
      else
        # For unknown types, pass through the whole data
        data
      end
    end

    # Loads all handler files from configured paths
    #
    # @return [void]
    def load_handlers
      config.handler_paths.each do |path|
        pattern = File.join(path, '**', '*.rb')
        Dir.glob(pattern).sort.each do |file|
          require file
        end
      end

      BoltRb.logger.info "[BoltRb] Loaded #{router.handler_count} handlers"
    end

    # Builds a Context object for the given payload
    #
    # @param payload [Hash] The event payload
    # @return [Context] The context for handler execution
    def build_context(payload)
      Context.new(
        payload: payload,
        client: client,
        ack: build_ack_fn(payload)
      )
    end

    # Builds the acknowledgement function for a payload
    #
    # Socket Mode acknowledgements are handled automatically by the
    # SocketMode::Client, so this returns a no-op for handlers.
    #
    # @param _payload [Hash] The event payload (unused)
    # @return [Proc] The ack function
    def build_ack_fn(_payload)
      # Socket Mode acks are handled automatically by the client
      # This allows handlers to call ack() without errors
      ->(_response = nil) {}
    end

    # Executes a single handler with error handling
    #
    # If the handler raises an exception, logs the error and calls
    # the configured error handler. Does not re-raise, allowing
    # other handlers to continue processing.
    #
    # @param handler_class [Class] The handler class to execute
    # @param context [Context] The context for handler execution
    # @return [void]
    def execute_handler(handler_class, context)
      handler_class.new(context).call
    rescue StandardError => e
      BoltRb.logger.error "[BoltRb] Error in #{handler_class}: #{e.message}"
      BoltRb.logger.error e.backtrace.first(5).join("\n")
      config.error_handler&.call(e, context.payload)
    end
  end
end
