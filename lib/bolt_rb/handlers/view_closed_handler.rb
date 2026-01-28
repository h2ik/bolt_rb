# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack view closed events (modal cancellation/dismissal)
    #
    # This handler provides the `view_closed` DSL for matching view_closed payloads.
    # View closed events are triggered when users close a modal by clicking the X
    # button or Cancel, but only when the modal was opened with notify_on_close: true.
    #
    # @example Basic modal close handler
    #   class CreateTicketCancelHandler < BoltRb::ViewClosedHandler
    #     view_closed 'create_ticket_modal'
    #
    #     def handle
    #       ack
    #       # Clean up any in-progress state
    #     end
    #   end
    #
    # @example Handler checking if view was cleared programmatically
    #   class SettingsCloseHandler < BoltRb::ViewClosedHandler
    #     view_closed 'settings_modal'
    #
    #     def handle
    #       ack
    #       unless is_cleared?
    #         # User manually closed, maybe prompt to save draft
    #       end
    #     end
    #   end
    #
    # @example Regex-based view matching
    #   class WizardCancelHandler < BoltRb::ViewClosedHandler
    #     view_closed /^wizard_step_/
    #
    #     def handle
    #       ack
    #       # Clean up wizard state for any step
    #     end
    #   end
    class ViewClosedHandler < Base
      class << self
        # Configures which callback_id this handler responds to
        #
        # @param callback_id [String, Regexp] The callback_id to match (exact string or regex)
        # @return [void]
        #
        # @example Match exact callback_id
        #   view_closed 'create_ticket_modal'
        #
        # @example Match callback_id pattern
        #   view_closed /^wizard_/
        def view_closed(callback_id)
          @matcher_config = {
            type: :view_closed,
            callback_id: callback_id
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks if the payload is a view_closed type and if the
        # callback_id matches the configured pattern.
        #
        # @param payload [Hash] The incoming Slack view_closed payload
        # @return [Boolean] true if this handler should process the close event
        def matches?(payload)
          return false unless matcher_config
          return false unless payload['type'] == 'view_closed'

          view_callback_id = payload.dig('view', 'callback_id')
          return false unless view_callback_id

          if matcher_config[:callback_id].is_a?(Regexp)
            matcher_config[:callback_id].match?(view_callback_id)
          else
            view_callback_id == matcher_config[:callback_id]
          end
        end
      end

      # Returns the view object from the payload
      #
      # @return [Hash, nil] The view object containing callback_id, private_metadata, etc.
      def view
        payload['view']
      end

      # Returns the callback_id from the view
      #
      # @return [String, nil] The callback_id
      def callback_id
        view&.dig('callback_id')
      end

      # Returns the private_metadata from the view
      #
      # Private metadata is a string field you can use to pass data between
      # the view open and close events. Often used to store IDs for cleanup.
      #
      # @return [String, nil] The private_metadata value
      def private_metadata
        view&.dig('private_metadata')
      end

      # Returns whether the view was cleared programmatically
      #
      # This is true when the view was dismissed via views.update with a
      # clear_on_close response, rather than the user clicking X or Cancel.
      #
      # @return [Boolean] true if the view was cleared programmatically
      def is_cleared?
        payload['is_cleared'] == true
      end

      # Returns the user ID from the payload
      #
      # @return [String, nil] The user ID who closed the modal
      def user_id
        payload.dig('user', 'id')
      end
    end
  end

  # Top-level alias for convenience
  ViewClosedHandler = Handlers::ViewClosedHandler
end
