# frozen_string_literal: true

module BoltRb
  module Handlers
    # Handler for Slack AI assistant threads.
    #
    # One subclass receives the three events that make up an assistant
    # conversation: `assistant_thread_started`,
    # `assistant_thread_context_changed`, and threaded direct messages
    # from the user.
    #
    # @example
    #   class MyAssistant < BoltRb::AssistantHandler
    #     def thread_started
    #       set_suggested_prompts(['Summarize this channel'])
    #     end
    #
    #     def user_message
    #       set_status('is thinking...')
    #       say("You said: #{text}")
    #     end
    #   end
    class AssistantHandler < Base
      THREAD_STARTED = 'assistant_thread_started'
      CONTEXT_CHANGED = 'assistant_thread_context_changed'
      MESSAGE = 'message'

      class << self
        # Match the assistant events and threaded user DMs
        #
        # @param payload [Hash] The incoming Slack event payload
        # @return [Boolean]
        def matches?(payload)
          # The abstract class is auto-registered but must never run
          return false if self == AssistantHandler

          event = payload['event']
          return false unless event

          case event['type']
          when THREAD_STARTED, CONTEXT_CHANGED then true
          when MESSAGE then user_thread_message?(event)
          else false
          end
        end

        private

        # Check for a human message inside a DM thread
        #
        # @param event [Hash] The message event
        # @return [Boolean]
        def user_thread_message?(event)
          return false unless event['channel_type'] == 'im'
          return false if event['thread_ts'].nil?
          return false if event['bot_id']
          return false if event['subtype']

          true
        end
      end

      # Route the event to the matching hook method
      #
      # @return [void]
      def handle
        case event['type']
        when THREAD_STARTED
          save_thread_context(assistant_thread['context'])
          thread_started
        when CONTEXT_CHANGED
          save_thread_context(assistant_thread['context'])
          context_changed
        when MESSAGE
          user_message
        end
      end

      # Hook for a new assistant thread
      #
      # @raise [NotImplementedError] Subclasses must define this method
      def thread_started
        raise NotImplementedError, "#{self.class} must implement #thread_started"
      end

      # Hook for a change of the user's active channel
      #
      # The new context is saved before this runs. The default does nothing.
      #
      # @return [void]
      def context_changed; end

      # Hook for a user message inside the assistant thread
      #
      # @raise [NotImplementedError] Subclasses must define this method
      def user_message
        raise NotImplementedError, "#{self.class} must implement #user_message"
      end

      # Return the event portion of the payload
      #
      # @return [Hash] The event data
      def event
        payload['event']
      end

      # Return the assistant_thread object for thread events
      #
      # @return [Hash, nil]
      def assistant_thread
        event['assistant_thread']
      end

      # Return the DM channel ID of the assistant thread
      #
      # @return [String, nil]
      def channel
        assistant_thread&.dig('channel_id') || event['channel']
      end

      # Return the thread timestamp of the assistant thread
      #
      # @return [String, nil]
      def thread_ts
        assistant_thread&.dig('thread_ts') || event['thread_ts']
      end

      # Return the user ID that owns the assistant thread
      #
      # @return [String, nil]
      def user
        assistant_thread&.dig('user_id') || event['user']
      end

      # Return the message text for user messages
      #
      # @return [String, nil]
      def text
        event['text']
      end

      # Return the context of the assistant thread
      #
      # Thread events carry the context in the payload. User messages read
      # it from the configured thread context store.
      #
      # @return [Hash, nil] Keys such as channel_id, team_id, enterprise_id
      def thread_context
        return assistant_thread['context'] if assistant_thread

        thread_context_store.get(channel_id: channel, thread_ts: thread_ts)
      end

      # Save a context for the current thread
      #
      # @param context [Hash] The context to save
      # @return [void]
      def save_thread_context(context)
        return if context.nil?

        thread_context_store.save(channel_id: channel, thread_ts: thread_ts, context: context)
      end

      # Post a message into the assistant thread
      #
      # @param message [String, Hash] Text or chat.postMessage options
      # @return [Hash] The Slack API response
      def say(message)
        options = message.is_a?(Hash) ? message : { text: message }
        client.chat_postMessage(options.merge(channel: channel, thread_ts: thread_ts))
      end

      # Set the status line shown while the assistant works
      #
      # @param status [String] Status text, for example 'is thinking...'
      # @return [Hash] The Slack API response
      def set_status(status)
        client.assistant_threads_setStatus(thread_target.merge(status: status))
      end

      # Set the title of the assistant thread
      #
      # @param title [String] The thread title
      # @return [Hash] The Slack API response
      def set_title(title)
        client.assistant_threads_setTitle(thread_target.merge(title: title))
      end

      # Set the suggested prompts shown to the user
      #
      # Plain strings become prompts with the same title and message.
      #
      # @param prompts [Array<String, Hash>] Up to four prompts
      # @param title [String, nil] Optional heading above the prompts
      # @return [Hash] The Slack API response
      def set_suggested_prompts(prompts, title: nil)
        options = thread_target.merge(prompts: normalize_prompts(prompts))
        options[:title] = title if title
        client.assistant_threads_setSuggestedPrompts(options)
      end

      private

      # Return the configured thread context store
      #
      # @return [Object]
      def thread_context_store
        BoltRb.configuration.assistant_thread_context_store
      end

      # Build the channel and thread arguments for assistant API calls
      #
      # @return [Hash]
      def thread_target
        { channel_id: channel, thread_ts: thread_ts }
      end

      # Convert prompt strings into title and message hashes
      #
      # @param prompts [Array<String, Hash>]
      # @return [Array<Hash>]
      def normalize_prompts(prompts)
        prompts.map do |prompt|
          prompt.is_a?(Hash) ? prompt : { title: prompt, message: prompt }
        end
      end
    end
  end

  # Top-level alias for convenience
  AssistantHandler = Handlers::AssistantHandler
end
