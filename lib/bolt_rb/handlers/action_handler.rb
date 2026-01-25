# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack interactive component actions (buttons, select menus, etc.)
    #
    # This handler provides the `action` DSL for matching block_actions payloads.
    # Block actions are triggered when users interact with interactive components
    # like buttons, overflow menus, date pickers, and select menus in messages
    # or modals.
    #
    # @example Basic button handler
    #   class ApproveHandler < BoltRb::ActionHandler
    #     action 'approve_button'
    #
    #     def handle
    #       ack
    #       say("Approved by <@#{user}>!")
    #     end
    #   end
    #
    # @example Handler with block_id filter
    #   class RequestApprovalHandler < BoltRb::ActionHandler
    #     action 'approve', block_id: 'approval_block'
    #
    #     def handle
    #       ack
    #       # Handle approval request
    #     end
    #   end
    #
    # @example Regex-based action matching
    #   class DynamicButtonHandler < BoltRb::ActionHandler
    #     action /^approve_request_/
    #
    #     def handle
    #       ack
    #       request_id = action_id.gsub('approve_request_', '')
    #       # Process the request
    #     end
    #   end
    class ActionHandler < Base
      class << self
        # Configures which action_id this handler responds to
        #
        # @param action_id [String, Regexp] The action_id to match (exact string or regex)
        # @param block_id [String, Regexp, nil] Optional block_id filter for more specific matching
        # @return [void]
        #
        # @example Match exact action_id
        #   action 'approve_button'
        #
        # @example Match with block_id
        #   action 'approve_button', block_id: 'approval_block'
        #
        # @example Match action_id pattern
        #   action /^approve_/
        def action(action_id, block_id: nil)
          @matcher_config = {
            type: :action,
            action_id: action_id,
            block_id: block_id
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks if the payload is a block_actions type and if any of the
        # actions in the payload match the configured action_id and optional block_id.
        #
        # @param payload [Hash] The incoming Slack block_actions payload
        # @return [Boolean] true if this handler should process the action
        def matches?(payload)
          return false unless matcher_config
          return false unless payload['type'] == 'block_actions'

          actions = payload['actions'] || []
          actions.any? do |action|
            action_matches?(action) && block_matches?(action)
          end
        end

        private

        # Checks if the action's action_id matches the configured pattern
        #
        # @param action [Hash] A single action from the payload
        # @return [Boolean] true if action_id matches
        def action_matches?(action)
          if matcher_config[:action_id].is_a?(Regexp)
            matcher_config[:action_id].match?(action['action_id'])
          else
            action['action_id'] == matcher_config[:action_id]
          end
        end

        # Checks if the action's block_id matches the configured pattern
        #
        # If no block_id is configured, this always returns true (no filtering).
        #
        # @param action [Hash] A single action from the payload
        # @return [Boolean] true if block_id matches or no block_id filter is set
        def block_matches?(action)
          return true if matcher_config[:block_id].nil?

          if matcher_config[:block_id].is_a?(Regexp)
            matcher_config[:block_id].match?(action['block_id'])
          else
            action['block_id'] == matcher_config[:block_id]
          end
        end
      end

      # Returns the first action from the payload
      #
      # Block actions payloads can contain multiple actions, but typically
      # only one action is triggered at a time. This returns the first action.
      #
      # @return [Hash, nil] The action hash containing action_id, value, etc.
      def action
        payload['actions']&.first
      end

      # Returns the action_id from the triggered action
      #
      # @return [String, nil] The action_id
      def action_id
        action&.dig('action_id')
      end

      # Returns the value from the triggered action
      #
      # For buttons this is the button's value. For select menus this is
      # the selected option's value.
      #
      # @return [String, nil] The action value
      def action_value
        action&.dig('value')
      end

      # Returns the block_id from the triggered action
      #
      # @return [String, nil] The block_id
      def block_id
        action&.dig('block_id')
      end

      # Returns the trigger_id for opening modals
      #
      # Slack provides a trigger_id with interactive actions that can be used
      # to open modals within 3 seconds of receiving the action.
      #
      # @return [String, nil] The trigger_id for views.open
      def trigger_id
        payload['trigger_id']
      end
    end
  end

  # Top-level alias for convenience
  ActionHandler = Handlers::ActionHandler
end
