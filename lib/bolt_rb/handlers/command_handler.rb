# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack slash commands (/deploy, /help, etc.)
    #
    # This handler provides the `command` DSL for matching slash command invocations.
    # Slash commands have a different payload structure than events, with fields like
    # `user_id`, `channel_id`, and `trigger_id` at the top level.
    #
    # @example Basic command handler
    #   class DeployHandler < BoltRb::CommandHandler
    #     command '/deploy'
    #
    #     def handle
    #       ack
    #       say("Deploying: #{command_text}")
    #     end
    #   end
    #
    # @example Command with modal
    #   class SettingsHandler < BoltRb::CommandHandler
    #     command '/settings'
    #
    #     def handle
    #       ack
    #       client.views_open(
    #         trigger_id: trigger_id,
    #         view: { type: 'modal', ... }
    #       )
    #     end
    #   end
    class CommandHandler < Base
      class << self
        # Configures which slash command this handler responds to
        #
        # @param command_name [String] The slash command to handle (e.g., '/deploy')
        # @return [void]
        #
        # @example
        #   command '/deploy'
        def command(command_name)
          @matcher_config = {
            type: :command,
            command: command_name
          }
        end

        # Determines if this handler matches the given payload
        #
        # Checks if the payload's command field matches the configured command.
        #
        # @param payload [Hash] The incoming Slack command payload
        # @return [Boolean] true if this handler should process the command
        def matches?(payload)
          return false unless matcher_config

          payload['command'] == matcher_config[:command]
        end
      end

      # Returns the slash command that was invoked
      #
      # @return [String] The command name (e.g., '/deploy')
      def command_name
        payload['command']
      end

      # Returns the text provided after the command
      #
      # For `/deploy production --force`, this returns "production --force"
      #
      # @return [String, nil] The text argument or nil if none provided
      def command_text
        payload['text']
      end

      # Returns the command parameters as a hash
      #
      # @return [Hash] Hash containing :text key with command text
      def params
        { text: command_text }
      end

      # Returns the trigger_id for opening modals
      #
      # Slack provides a trigger_id with slash commands that can be used
      # to open modals within 3 seconds of receiving the command.
      #
      # @return [String, nil] The trigger_id for views.open
      def trigger_id
        payload['trigger_id']
      end

      # Returns the user ID who invoked the command
      #
      # Overrides Base#user because slash command payloads use 'user_id'
      # instead of nested event.user structure.
      #
      # @return [String, nil] The user ID
      def user
        payload['user_id'] || super
      end

      # Returns the channel ID where the command was invoked
      #
      # Overrides Base#channel because slash command payloads use 'channel_id'
      # instead of nested event.channel structure.
      #
      # @return [String, nil] The channel ID
      def channel
        payload['channel_id'] || super
      end
    end
  end

  # Top-level alias for convenience
  CommandHandler = Handlers::CommandHandler
end
