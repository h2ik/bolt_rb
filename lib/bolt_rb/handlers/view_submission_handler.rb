# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack view submissions (modal form submissions)
    #
    # This handler provides the `view` DSL for matching view_submission payloads.
    # View submissions are triggered when users click the submit button on modals
    # opened via views.open or views.push.
    #
    # @example Basic modal submission handler
    #   class CreateTicketSubmitHandler < BoltRb::ViewSubmissionHandler
    #     view 'create_ticket_modal'
    #
    #     def handle
    #       ack
    #       # Process the form submission
    #       ticket_title = values.dig('title_block', 'title_input', 'value')
    #     end
    #   end
    #
    # @example Handler with validation errors
    #   class ValidatedSubmitHandler < BoltRb::ViewSubmissionHandler
    #     view 'validated_form'
    #
    #     def handle
    #       if invalid_input?
    #         ack(response_action: 'errors', errors: { 'input_block' => 'Invalid input' })
    #       else
    #         ack
    #         process_submission
    #       end
    #     end
    #   end
    #
    # @example Regex-based view matching
    #   class DynamicFormHandler < BoltRb::ViewSubmissionHandler
    #     view /^form_step_/
    #
    #     def handle
    #       ack
    #       step = callback_id.gsub('form_step_', '')
    #       # Handle based on step
    #     end
    #   end
    class ViewSubmissionHandler < Base
      class << self
        # Configures which callback_id this handler responds to
        #
        # @param callback_id [String, Regexp] The callback_id to match (exact string or regex)
        # @return [void]
        #
        # @example Match exact callback_id
        #   view 'create_ticket_modal'
        #
        # @example Match callback_id pattern
        #   view /^create_/
        def view(callback_id)
          @matcher_config = {
            type: :view_submission,
            callback_id: callback_id
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks if the payload is a view_submission type and if the
        # callback_id matches the configured pattern.
        #
        # @param payload [Hash] The incoming Slack view_submission payload
        # @return [Boolean] true if this handler should process the submission
        def matches?(payload)
          return false unless matcher_config
          return false unless payload['type'] == 'view_submission'

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
      # @return [Hash, nil] The view object containing callback_id, private_metadata, state, etc.
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
      # the view open and submission events. Often used to store IDs.
      #
      # @return [String, nil] The private_metadata value
      def private_metadata
        view&.dig('private_metadata')
      end

      # Returns the state values from the submitted form
      #
      # The values hash is keyed by block_id, then action_id, then contains
      # the input value (format depends on input type).
      #
      # @return [Hash] The form values hash
      # @example Structure
      #   {
      #     'title_block' => {
      #       'title_input' => { 'type' => 'plain_text_input', 'value' => 'My Title' }
      #     },
      #     'select_block' => {
      #       'select_input' => { 'type' => 'static_select', 'selected_option' => { 'value' => 'opt1' } }
      #     }
      #   }
      def values
        view&.dig('state', 'values') || {}
      end

      # Returns the user ID from the payload
      #
      # @return [String, nil] The user ID who submitted the form
      def user_id
        payload.dig('user', 'id')
      end

      # Returns the response URLs for block-based responses
      #
      # Only present if the modal was opened from a message interaction.
      #
      # @return [Array<Hash>] Array of response_url objects
      def response_urls
        payload['response_urls'] || []
      end

      # Returns the hash value of the submitted view
      #
      # Used for optimistic locking when updating views.
      #
      # @return [String, nil] The view hash
      def view_hash
        view&.dig('hash')
      end
    end
  end

  # Top-level alias for convenience
  ViewSubmissionHandler = Handlers::ViewSubmissionHandler
end
