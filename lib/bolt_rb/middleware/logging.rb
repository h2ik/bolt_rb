# frozen_string_literal: true

module BoltRb
  module Middleware
    # Logging middleware for request/response logging
    #
    # Logs the event type being processed and the time taken to process it.
    # This is useful for debugging and monitoring your Bolt application.
    #
    # @example Output
    #   [BoltRb] Processing event:message
    #   [BoltRb] Completed event:message in 12.34ms
    class Logging < Base
      # Processes the request with logging
      #
      # Logs the event type before processing and the elapsed time after.
      #
      # @param context [BoltRb::Context] The request context
      # @yield Continues to the next middleware in the chain
      # @return [void]
      def call(context)
        event_type = determine_event_type(context.payload)
        BoltRb.logger.info "[BoltRb] Processing #{event_type}"
        started = Time.now

        yield if block_given?

        elapsed = ((Time.now - started) * 1000).round(2)
        BoltRb.logger.info "[BoltRb] Completed #{event_type} in #{elapsed}ms"
      end

      private

      # Determines the event type from the payload
      #
      # Handles various payload formats from Slack:
      # - Events API: event.type
      # - Slash commands: command
      # - Block actions: type with action_ids
      # - Shortcuts: type with callback_id
      # - View submissions: view_submission with callback_id
      # - View closed: view_closed with callback_id
      #
      # @param payload [Hash] The raw Slack payload
      # @return [String] A descriptive event type string
      def determine_event_type(payload)
        if payload['event']
          "event:#{payload['event']['type']}"
        elsif payload['command']
          "command:#{payload['command']}"
        elsif payload['type'] == 'block_actions'
          action_ids = payload['actions']&.map { |a| a['action_id'] }&.join(',')
          "action:#{action_ids}"
        elsif payload['type'] == 'shortcut' || payload['type'] == 'message_action'
          "shortcut:#{payload['callback_id']}"
        elsif payload['type'] == 'view_submission'
          "view_submission:#{payload.dig('view', 'callback_id')}"
        elsif payload['type'] == 'view_closed'
          "view_closed:#{payload.dig('view', 'callback_id')}"
        else
          'unknown'
        end
      end
    end
  end
end
