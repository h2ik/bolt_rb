# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack shortcuts (global shortcuts and message shortcuts)
    #
    # This handler provides the `shortcut` DSL for matching shortcut payloads.
    # Global shortcuts are triggered from the lightning bolt menu in Slack,
    # while message shortcuts appear in the context menu of messages.
    #
    # @example Global shortcut handler
    #   class CreateTicketHandler < BoltRb::ShortcutHandler
    #     shortcut 'create_ticket'
    #
    #     def handle
    #       ack
    #       # Open a modal with views.open using trigger_id
    #     end
    #   end
    #
    # @example Message shortcut handler
    #   class QuoteMessageHandler < BoltRb::ShortcutHandler
    #     shortcut 'quote_message'
    #
    #     def handle
    #       ack
    #       text = message_text
    #       # Do something with the quoted message
    #     end
    #   end
    #
    # @example Regex-based shortcut matching
    #   class CreateHandler < BoltRb::ShortcutHandler
    #     shortcut /^create_/
    #
    #     def handle
    #       ack
    #       # Handle any shortcut starting with 'create_'
    #     end
    #   end
    class ShortcutHandler < Base
      # Valid shortcut payload types
      # 'shortcut' is a global shortcut (from lightning bolt menu)
      # 'message_action' is a message shortcut (from message context menu)
      SHORTCUT_TYPES = %w[shortcut message_action].freeze

      class << self
        # Configures which callback_id this handler responds to
        #
        # @param callback_id [String, Regexp] The callback_id to match (exact string or regex)
        # @return [void]
        #
        # @example Match exact callback_id
        #   shortcut 'create_ticket'
        #
        # @example Match callback_id pattern
        #   shortcut /^create_/
        def shortcut(callback_id)
          @matcher_config = {
            type: :shortcut,
            callback_id: callback_id
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks if the payload is a shortcut or message_action type and if the
        # callback_id matches the configured pattern.
        #
        # @param payload [Hash] The incoming Slack shortcut payload
        # @return [Boolean] true if this handler should process the shortcut
        def matches?(payload)
          return false unless matcher_config
          return false unless SHORTCUT_TYPES.include?(payload['type'])

          if matcher_config[:callback_id].is_a?(Regexp)
            matcher_config[:callback_id].match?(payload['callback_id'])
          else
            payload['callback_id'] == matcher_config[:callback_id]
          end
        end
      end

      # Returns the callback_id from the shortcut payload
      #
      # @return [String, nil] The callback_id
      def callback_id
        payload['callback_id']
      end

      # Returns the trigger_id for opening modals
      #
      # Slack provides a trigger_id with shortcuts that can be used
      # to open modals within 3 seconds of receiving the shortcut.
      #
      # @return [String, nil] The trigger_id for views.open
      def trigger_id
        payload['trigger_id']
      end

      # Returns the type of shortcut (:global or :message)
      #
      # @return [Symbol] :message for message shortcuts (message_action),
      #   :global for global shortcuts
      def shortcut_type
        payload['type'] == 'message_action' ? :message : :global
      end

      # Returns the message object for message shortcuts
      #
      # Only available for message shortcuts (message_action type).
      # Contains the original message that the shortcut was triggered on.
      #
      # @return [Hash, nil] The message object or nil for global shortcuts
      def message
        payload['message']
      end

      # Returns the text of the message for message shortcuts
      #
      # Convenience method to get the message text directly.
      #
      # @return [String, nil] The message text or nil if not available
      def message_text
        message&.dig('text')
      end
    end
  end

  # Top-level alias for convenience
  ShortcutHandler = Handlers::ShortcutHandler
end
