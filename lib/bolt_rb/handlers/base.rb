# frozen_string_literal: true

module BoltRb
  module Handlers
    # Base class for all Slack event handlers.
    #
    # This provides the common interface and middleware execution that all
    # handler types (Event, Command, Action, Shortcut) inherit from.
    #
    # Subclasses should:
    # - Override .matches?(payload) to define matching logic
    # - Override #handle to implement the handler behavior
    # - Optionally use .use(middleware) to add handler-specific middleware
    #
    # @example Creating a custom handler
    #   class MyHandler < BoltRb::Handlers::Base
    #     use MyCustomMiddleware
    #
    #     def self.matches?(payload)
    #       payload.dig('event', 'type') == 'message'
    #     end
    #
    #     def handle
    #       say("Received your message!")
    #     end
    #   end
    class Base
      class << self
        # Configuration for matching this handler to payloads
        # Subclasses should set this to define their matching criteria
        #
        # @return [Object, nil] The matcher configuration
        attr_reader :matcher_config

        # Returns the middleware stack for this handler class
        #
        # @return [Array<Class>] Array of middleware classes
        def middleware_stack
          @middleware_stack ||= []
        end

        # Adds middleware to this handler's stack
        #
        # Middleware is executed in the order added, wrapping the #handle method.
        # Each middleware should call yield to continue the chain.
        #
        # @param middleware_class [Class] The middleware class to add
        # @return [void]
        #
        # @example Adding middleware
        #   class MyHandler < Base
        #     use LoggingMiddleware
        #     use AuthenticationMiddleware
        #   end
        def use(middleware_class)
          middleware_stack << middleware_class
        end

        # Determines if this handler matches the given payload
        #
        # Base implementation always returns false. Subclasses should override
        # this to implement their matching logic.
        #
        # @param _payload [Hash] The incoming Slack payload
        # @return [Boolean] true if this handler should process the payload
        def matches?(_payload)
          false
        end

        # Hook called when a class inherits from Base
        #
        # Ensures each subclass gets its own independent middleware stack
        # and registers the handler with the global router.
        #
        # @param subclass [Class] The inheriting class
        # @return [void]
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@middleware_stack, [])
          # Auto-register with the global router
          BoltRb.router.register(subclass)
        end
      end

      # @return [Context] The context object for this handler invocation
      attr_reader :context

      # Creates a new handler instance
      #
      # @param context [Context] The context containing payload, client, and ack
      def initialize(context)
        @context = context
      end

      # Returns the raw payload from the context
      #
      # @return [Hash] The Slack event payload
      def payload
        context.payload
      end

      # Returns the Slack Web API client
      #
      # @return [Slack::Web::Client] The API client
      def client
        context.client
      end

      # Returns the user ID from the context
      #
      # @return [String, nil] The user ID
      def user
        context.user
      end

      # Returns the channel ID from the context
      #
      # @return [String, nil] The channel ID
      def channel
        context.channel
      end

      # Posts a message to the channel
      #
      # Delegates to Context#say
      #
      # @param message [String, Hash] The message to post
      # @return [Hash] The Slack API response
      def say(message)
        context.say(message)
      end

      # Acknowledges the event
      #
      # Delegates to Context#ack
      #
      # @param response [String, Hash, nil] Optional response to include
      # @return [void]
      def ack(response = nil)
        context.ack(response)
      end

      # Responds using the response_url
      #
      # Delegates to Context#respond
      #
      # @param message [String, Hash] The message to send
      # @return [Net::HTTPResponse, nil] The HTTP response
      def respond(message)
        context.respond(message)
      end

      # Executes this handler
      #
      # Runs the middleware stack, then calls #handle at the end of the chain.
      #
      # @return [void]
      def call
        run_middleware { handle }
      end

      # The main handler logic
      #
      # Subclasses must override this method to implement their behavior.
      #
      # @raise [NotImplementedError] Always raises in the base class
      def handle
        raise NotImplementedError, 'Subclasses must implement #handle'
      end

      private

      # Executes the middleware chain, then the given block
      #
      # Creates a recursive chain where each middleware can call yield
      # to invoke the next middleware (or the final block).
      #
      # @yield The block to execute at the end of the chain
      # @return [void]
      def run_middleware(&block)
        chain = self.class.middleware_stack.dup
        run_next = proc do
          if chain.empty?
            block.call
          else
            middleware = chain.shift.new
            middleware.call(context) { run_next.call }
          end
        end
        run_next.call
      end
    end
  end
end
