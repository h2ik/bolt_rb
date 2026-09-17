# frozen_string_literal: true

module BoltRb
  module Assistant
    # In-memory store for assistant thread context.
    #
    # Slack sends the user's active channel with `assistant_thread_started`
    # and `assistant_thread_context_changed`. This store keeps that context
    # so later user messages in the same thread can read it.
    #
    # Data lives only in the current process. Give
    # `BoltRb.configuration.assistant_thread_context_store` an object with
    # the same `get` and `save` methods to persist across processes.
    #
    # @example Custom store
    #   class RedisThreadContextStore
    #     def get(channel_id:, thread_ts:)
    #       json = redis.get("assistant:#{channel_id}:#{thread_ts}")
    #       json && JSON.parse(json)
    #     end
    #
    #     def save(channel_id:, thread_ts:, context:)
    #       redis.set("assistant:#{channel_id}:#{thread_ts}", context.to_json)
    #     end
    #   end
    class MemoryThreadContextStore
      def initialize
        @contexts = {}
        @mutex = Mutex.new
      end

      # Read the saved context for a thread
      #
      # @param channel_id [String] The DM channel ID
      # @param thread_ts [String] The thread timestamp
      # @return [Hash, nil] The saved context or nil
      def get(channel_id:, thread_ts:)
        @mutex.synchronize { @contexts[key(channel_id, thread_ts)] }
      end

      # Save the context for a thread
      #
      # @param channel_id [String] The DM channel ID
      # @param thread_ts [String] The thread timestamp
      # @param context [Hash] The context to save
      # @return [void]
      def save(channel_id:, thread_ts:, context:)
        @mutex.synchronize { @contexts[key(channel_id, thread_ts)] = context }
      end

      private

      # Build the lookup key for a thread
      #
      # @return [String]
      def key(channel_id, thread_ts)
        "#{channel_id}:#{thread_ts}"
      end
    end
  end
end
