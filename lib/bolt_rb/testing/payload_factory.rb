# frozen_string_literal: true

require 'securerandom'

module BoltRb
  module Testing
    # Factory class for creating fake Slack payloads for testing purposes.
    #
    # This class provides methods to generate realistic payloads for various
    # Slack event types, making it easy to write specs for handlers without
    # needing actual Slack events.
    #
    # @example Creating a message event payload
    #   payload = BoltRb::Testing::PayloadFactory.message(text: 'hello')
    #   # => { 'type' => 'event_callback', 'event' => { 'type' => 'message', ... } }
    #
    # @example Creating a slash command payload
    #   payload = BoltRb::Testing::PayloadFactory.command(command: '/deploy', text: 'production')
    #   # => { 'command' => '/deploy', 'text' => 'production', ... }
    class PayloadFactory
      class << self
        # Creates a message event payload
        #
        # @param text [String] The message text
        # @param user [String] The user ID (default: 'U123TEST')
        # @param channel [String] The channel ID (default: 'C456TEST')
        # @param ts [String, nil] The timestamp (auto-generated if nil)
        # @param thread_ts [String, nil] The thread timestamp for threaded messages
        # @return [Hash] The message event payload
        def message(text:, user: 'U123TEST', channel: 'C456TEST', ts: nil, thread_ts: nil)
          {
            'type' => 'event_callback',
            'event' => {
              'type' => 'message',
              'text' => text,
              'user' => user,
              'channel' => channel,
              'ts' => ts || generate_ts,
              'thread_ts' => thread_ts
            }.compact
          }
        end

        # Creates an app_mention event payload
        #
        # @param text [String] The mention text (should include the bot mention)
        # @param user [String] The user ID (default: 'U123TEST')
        # @param channel [String] The channel ID (default: 'C456TEST')
        # @return [Hash] The app_mention event payload
        def app_mention(text:, user: 'U123TEST', channel: 'C456TEST')
          {
            'type' => 'event_callback',
            'event' => {
              'type' => 'app_mention',
              'text' => text,
              'user' => user,
              'channel' => channel,
              'ts' => generate_ts
            }
          }
        end

        # Creates a slash command payload
        #
        # @param command [String] The command name (e.g., '/deploy')
        # @param text [String] The text after the command (default: '')
        # @param user [String] The user ID (default: 'U123TEST')
        # @param channel [String] The channel ID (default: 'C456TEST')
        # @return [Hash] The command payload
        def command(command:, text: '', user: 'U123TEST', channel: 'C456TEST')
          {
            'command' => command,
            'text' => text,
            'user_id' => user,
            'channel_id' => channel,
            'response_url' => 'https://hooks.slack.com/commands/T123/456/xxx',
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }
        end

        # Creates a block_actions payload for interactive components
        #
        # @param action_id [String] The action ID of the interactive component
        # @param value [String, nil] The value of the action
        # @param user [String] The user ID (default: 'U123TEST')
        # @param block_id [String, nil] The block ID (default: 'block_1')
        # @param channel [String] The channel ID (default: 'C456TEST')
        # @return [Hash] The block_actions payload
        def action(action_id:, value: nil, user: 'U123TEST', block_id: nil, channel: 'C456TEST')
          {
            'type' => 'block_actions',
            'user' => { 'id' => user },
            'channel' => { 'id' => channel },
            'actions' => [{
              'action_id' => action_id,
              'block_id' => block_id || 'block_1',
              'value' => value
            }.compact],
            'response_url' => 'https://hooks.slack.com/actions/T123/456/xxx',
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }
        end

        # Creates a shortcut payload (global or message)
        #
        # @param callback_id [String] The callback ID of the shortcut
        # @param user [String] The user ID (default: 'U123TEST')
        # @param type [Symbol] The shortcut type (:global or :message)
        # @param message_text [String, nil] The message text for message shortcuts
        # @return [Hash] The shortcut payload
        def shortcut(callback_id:, user: 'U123TEST', type: :global, message_text: nil)
          payload = {
            'type' => type == :message ? 'message_action' : 'shortcut',
            'callback_id' => callback_id,
            'user' => { 'id' => user },
            'trigger_id' => "trigger_#{SecureRandom.hex(8)}"
          }

          if type == :message
            payload['channel'] = { 'id' => 'C456TEST' }
            payload['message'] = {
              'type' => 'message',
              'text' => message_text || 'Original message',
              'user' => 'U789MSG',
              'ts' => generate_ts
            }
          end

          payload
        end

        private

        # Generates a fake Slack timestamp
        #
        # @return [String] A timestamp in Slack's format (epoch.random)
        def generate_ts
          "#{Time.now.to_i}.#{SecureRandom.hex(3)}"
        end
      end
    end
  end
end
