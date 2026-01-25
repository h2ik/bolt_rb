# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack events (message, app_mention, reaction_added, etc.)
    #
    # This handler provides the `listen_to` DSL for matching event types
    # and optionally filtering by text patterns.
    #
    # @example Basic message handler
    #   class GreetingHandler < BoltRb::EventHandler
    #     listen_to :message
    #
    #     def handle
    #       say("Hello, #{user}!")
    #     end
    #   end
    #
    # @example Handler with pattern matching
    #   class HelloHandler < BoltRb::EventHandler
    #     listen_to :message, pattern: /hello/i
    #
    #     def handle
    #       say("Hello to you too!")
    #     end
    #   end
    #
    # @example App mention handler
    #   class MentionHandler < BoltRb::EventHandler
    #     listen_to :app_mention
    #
    #     def handle
    #       say("You mentioned me in #{channel}!")
    #     end
    #   end
    class EventHandler < Base
      class << self
        # Configures which event type this handler responds to
        #
        # @param event_type [Symbol, String] The Slack event type to listen for
        #   (e.g., :message, :app_mention, :reaction_added)
        # @param pattern [Regexp, nil] Optional regex pattern to match against
        #   the event's text field
        # @return [void]
        #
        # @example Listen to all messages
        #   listen_to :message
        #
        # @example Listen to messages matching a pattern
        #   listen_to :message, pattern: /help/i
        def listen_to(event_type, pattern: nil)
          @matcher_config = {
            type: :event,
            event_type: event_type,
            pattern: pattern
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks the event type and optionally the text pattern.
        #
        # @param payload [Hash] The incoming Slack event payload
        # @return [Boolean] true if this handler should process the event
        def matches?(payload)
          return false unless matcher_config

          event = payload['event']
          return false unless event
          return false unless event['type'].to_s == matcher_config[:event_type].to_s

          if matcher_config[:pattern]
            return false if event['text'].nil?
            return matcher_config[:pattern].match?(event['text'])
          end

          true
        end
      end

      # Returns the event portion of the payload
      #
      # @return [Hash, nil] The event data
      def event
        payload['event']
      end

      # Returns the text content of the event
      #
      # @return [String, nil] The message text
      def text
        event&.dig('text')
      end

      # Returns the thread timestamp if this message is in a thread
      #
      # @return [String, nil] The thread_ts value
      def thread_ts
        event&.dig('thread_ts')
      end

      # Returns the message timestamp
      #
      # @return [String, nil] The ts value
      def ts
        event&.dig('ts')
      end
    end
  end

  # Top-level alias for convenience
  EventHandler = Handlers::EventHandler
end
