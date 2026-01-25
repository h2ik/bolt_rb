# frozen_string_literal: true

require 'net/http'
require 'json'

module BoltRb
  # Context wraps the incoming Slack event payload and provides
  # convenience methods for responding to events.
  #
  # This is the object passed to event handlers and provides access to:
  # - The raw payload data
  # - The Slack Web API client
  # - Helper methods like say(), ack(), and respond()
  #
  # @example Basic usage in an event handler
  #   app.event('message') do |ctx|
  #     ctx.say("You said: #{ctx.text}")
  #   end
  #
  # @example Using respond for slash commands
  #   app.command('/echo') do |ctx|
  #     ctx.ack
  #     ctx.respond("Echoing: #{ctx.text}")
  #   end
  class Context
    # @return [Hash] The raw payload from the Slack event
    attr_reader :payload

    # @return [Slack::Web::Client] The Slack Web API client
    attr_reader :client

    # Creates a new Context instance
    #
    # @param payload [Hash] The raw event payload from Slack
    # @param client [Slack::Web::Client] The Slack Web API client
    # @param ack [Proc] The acknowledgement function to call
    def initialize(payload:, client:, ack:)
      @payload = payload
      @client = client
      @ack_fn = ack
      @acked = false
    end

    # Returns the event portion of the payload
    #
    # @return [Hash, nil] The event data or nil if not present
    def event
      payload['event']
    end

    # Extracts the user ID from the payload
    #
    # Handles various payload formats:
    # - event.user (string)
    # - user_id (slash commands)
    # - user (string)
    # - user.id (nested object)
    #
    # @return [String, nil] The user ID or nil if not found
    def user
      extract_id(
        payload.dig('event', 'user') ||
        payload['user_id'] ||
        payload['user'] ||
        payload.dig('user', 'id')
      )
    end

    # Extracts the channel ID from the payload
    #
    # Handles various payload formats:
    # - event.channel (string)
    # - channel_id (slash commands)
    # - channel (string)
    # - channel.id (nested object)
    #
    # @return [String, nil] The channel ID or nil if not found
    def channel
      extract_id(
        payload.dig('event', 'channel') ||
        payload['channel_id'] ||
        payload['channel'] ||
        payload.dig('channel', 'id')
      )
    end

    # Extracts the text content from the event
    #
    # @return [String, nil] The message text or nil if not present
    def text
      event&.dig('text')
    end

    # Acknowledges the event
    #
    # For events that require acknowledgement (slash commands, interactive
    # components), this method sends the acknowledgement to Slack.
    #
    # @param response [String, Hash, nil] Optional response to include with the ack
    # @return [void]
    def ack(response = nil)
      @ack_fn.call(response)
      @acked = true
    end

    # Returns whether this context has been acknowledged
    #
    # @return [Boolean] true if ack() has been called
    def acked?
      @acked
    end

    # Posts a message to the channel
    #
    # @param message [String, Hash] The message to post. Can be a simple string
    #   or a hash with chat.postMessage options
    # @return [Hash] The response from the Slack API
    #
    # @example Simple text message
    #   ctx.say("Hello!")
    #
    # @example Message with options
    #   ctx.say(text: "Hello!", thread_ts: "123.456")
    def say(message)
      options = message.is_a?(Hash) ? message : { text: message }
      client.chat_postMessage(options.merge(channel: channel))
    end

    # Responds using the response_url
    #
    # This is used for slash commands and interactive components where
    # Slack provides a response_url for sending follow-up messages.
    #
    # @param message [String, Hash] The message to send. Can be a simple string
    #   or a hash with response options (text, blocks, response_type, etc.)
    # @return [Net::HTTPResponse, nil] The HTTP response or nil if no response_url
    #
    # @example Simple response
    #   ctx.respond("Processing complete!")
    #
    # @example Ephemeral response with blocks
    #   ctx.respond(
    #     text: "Here's your data",
    #     response_type: "ephemeral",
    #     blocks: [...]
    #   )
    def respond(message)
      response_url = payload['response_url']
      return unless response_url

      options = message.is_a?(Hash) ? message : { text: message }
      uri = URI(response_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request.body = options.to_json
      http.request(request)
    end

    private

    # Extracts an ID from a value that might be a string or hash
    #
    # @param value [String, Hash, nil] The value to extract from
    # @return [String, nil] The extracted ID
    def extract_id(value)
      return nil if value.nil?

      value.is_a?(Hash) ? value['id'] : value
    end
  end
end
