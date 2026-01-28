# frozen_string_literal: true

require 'websocket-client-simple'
require 'net/http'
require 'uri'
require 'json'

module BoltRb
  module SocketMode
    # WebSocket client for Slack Socket Mode connections
    #
    # Handles the WebSocket lifecycle including:
    # - Obtaining a connection URL via apps.connections.open
    # - Establishing and maintaining the WebSocket connection
    # - Acknowledging received events
    # - Automatic reconnection on disconnect
    #
    # @example Basic usage
    #   client = BoltRb::SocketMode::Client.new(
    #     app_token: 'xapp-...',
    #     logger: Logger.new(STDOUT)
    #   )
    #   client.on_message { |payload| handle_event(payload) }
    #   client.start
    class Client
      SLACK_API_URL = 'https://slack.com/api/apps.connections.open'
      RECONNECT_DELAY = 5

      # @return [String] The Slack app-level token
      attr_reader :app_token

      # @return [Logger] The logger instance
      attr_reader :logger

      # Creates a new Socket Mode client
      #
      # @param app_token [String] The Slack app-level token (xapp-...)
      # @param logger [Logger] Logger instance for output
      def initialize(app_token:, logger: nil)
        @app_token = app_token
        @logger = logger || Logger.new($stdout)
        @running = false
        @websocket = nil
        @message_handlers = []
      end

      # Registers a handler for incoming messages
      #
      # @yield [Hash] The parsed event payload
      # @return [void]
      def on_message(&block)
        @message_handlers << block
      end

      # Starts the Socket Mode connection
      #
      # Obtains a WebSocket URL and establishes the connection.
      # This method blocks until stop is called.
      #
      # @return [void]
      def start
        @running = true
        connect_with_retry
        run_loop
      end

      # Stops the Socket Mode connection
      #
      # @return [void]
      def stop
        @running = false
        @websocket&.close
      end

      # Requests a stop - safe to call from trap context
      #
      # Only sets the running flag to false. Does NOT close the websocket
      # or perform any operations that might use mutexes, as this is
      # designed to be called from signal trap handlers.
      #
      # @return [void]
      def request_stop
        @running = false
      end

      # @return [Boolean] Whether the client is currently running
      def running?
        @running
      end

      # @return [Boolean] Whether the WebSocket is connected
      def connected?
        @websocket&.open?
      end

      private

      # Main run loop that keeps the connection alive
      #
      # @return [void]
      def run_loop
        last_heartbeat = Time.now
        heartbeat_interval = 60 # Log every 60 seconds

        while @running
          sleep 0.1
          reconnect_if_needed

          # Periodic heartbeat to confirm the loop is alive
          if Time.now - last_heartbeat >= heartbeat_interval
            logger.debug "[SocketMode] Heartbeat: connected=#{connected?}, websocket_open=#{@websocket&.open?}"
            last_heartbeat = Time.now
          end
        end
      ensure
        # Clean up websocket when loop exits
        @websocket&.close
      end

      # Reconnects if the WebSocket is disconnected
      #
      # @return [void]
      def reconnect_if_needed
        return if !@running || connected?

        logger.info '[SocketMode] Connection lost, reconnecting...'
        sleep RECONNECT_DELAY
        connect_with_retry
      end

      # Attempts to connect with retry logic
      #
      # @return [void]
      def connect_with_retry
        retries = 0
        max_retries = 5

        begin
          connect
        rescue StandardError => e
          retries += 1
          if retries <= max_retries
            logger.warn "[SocketMode] Connection failed (attempt #{retries}/#{max_retries}): #{e.message}"
            sleep RECONNECT_DELAY
            retry
          else
            logger.error "[SocketMode] Max retries exceeded, giving up: #{e.message}"
            @running = false
          end
        end
      end

      # Establishes the WebSocket connection
      #
      # @return [void]
      def connect
        url = obtain_websocket_url
        logger.info '[SocketMode] Connecting to Slack...'

        client = self
        @websocket = WebSocket::Client::Simple.connect(url)

        @websocket.on :open do
          client.send(:handle_open)
        end

        @websocket.on :message do |msg|
          client.send(:handle_message, msg)
        end

        @websocket.on :error do |e|
          client.send(:handle_error, e)
        end

        @websocket.on :close do |e|
          client.send(:handle_close, e)
        end

        # Wait for connection to establish
        sleep 0.5 until @websocket.open? || !@running
      end

      # Obtains a WebSocket URL from Slack
      #
      # @return [String] The WebSocket URL
      # @raise [RuntimeError] If unable to obtain URL
      def obtain_websocket_url
        uri = URI.parse(SLACK_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request['Authorization'] = "Bearer #{app_token}"
        request['Content-Type'] = 'application/x-www-form-urlencoded'

        response = http.request(request)
        body = JSON.parse(response.body)

        unless body['ok']
          raise "Failed to obtain WebSocket URL: #{body['error']}"
        end

        body['url']
      end

      # Handles WebSocket open event
      #
      # @return [void]
      def handle_open
        logger.info '[SocketMode] Connected to Slack'
      end

      # Handles incoming WebSocket message
      #
      # @param msg [WebSocket::Client::Simple::Message] The message
      # @return [void]
      def handle_message(msg)
        raw_data = msg.data
        logger.debug "[SocketMode] Raw message received: #{raw_data.nil? ? '(nil)' : raw_data[0, 200]}"

        # Skip nil, empty, or non-JSON data (like WebSocket ping/pong frames)
        return if msg.data.nil? || msg.data.empty? || !msg.data.start_with?('{')

        data = JSON.parse(msg.data)

        # Handle Slack's control messages
        case data['type']
        when 'hello'
          logger.debug '[SocketMode] Received hello from Slack'
          return
        when 'disconnect'
          logger.info "[SocketMode] Disconnect requested: #{data['reason']}"
          @websocket&.close
          return
        when 'ping'
          handle_ping(data)
          return
        end

        # Acknowledge the event
        acknowledge(data['envelope_id']) if data['envelope_id']

        # Dispatch to handlers
        dispatch_event(data)
      rescue JSON::ParserError => e
        logger.error "[SocketMode] Failed to parse message: #{e.message}"
      rescue StandardError => e
        logger.error "[SocketMode] Error handling message: #{e.message}"
        logger.error e.backtrace.first(5).join("\n")
      end

      # Handles WebSocket error
      #
      # @param error [Exception] The error
      # @return [void]
      def handle_error(error)
        logger.error "[SocketMode] WebSocket error: #{error.message}"
      end

      # Handles WebSocket close
      #
      # @param event [Object] The close event
      # @return [void]
      def handle_close(event)
        logger.info "[SocketMode] WebSocket closed: #{event}"
      end

      # Handles Slack Socket Mode ping message
      #
      # Responds with a pong message echoing back the num field
      # @param data [Hash] The ping message data
      # @return [void]
      def handle_ping(data)
        return unless @websocket&.open?

        pong = { 'type' => 'pong' }
        pong['num'] = data['num'] if data['num']
        @websocket.send(pong.to_json)
        logger.debug "[SocketMode] Responded to ping#{data['num'] ? " (num: #{data['num']})" : ''}"
      end

      # Sends an acknowledgement for an event
      #
      # @param envelope_id [String] The envelope ID to acknowledge
      # @return [void]
      def acknowledge(envelope_id)
        return unless @websocket&.open?

        ack = { envelope_id: envelope_id }.to_json
        @websocket.send(ack)
        logger.debug "[SocketMode] Acknowledged envelope: #{envelope_id}"
      end

      # Dispatches an event to registered handlers
      #
      # @param data [Hash] The event data
      # @return [void]
      def dispatch_event(data)
        @message_handlers.each do |handler|
          handler.call(data)
        rescue StandardError => e
          logger.error "[SocketMode] Handler error: #{e.message}"
          logger.error e.backtrace.first(5).join("\n")
        end
      end
    end
  end
end
