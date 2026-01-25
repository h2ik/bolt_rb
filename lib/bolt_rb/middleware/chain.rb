# frozen_string_literal: true

module BoltRb
  module Middleware
    # Executes a chain of middleware in order
    #
    # The middleware chain follows the onion model where each middleware
    # can execute code before and after the next middleware in the chain.
    # This is similar to Rack middleware or Rails around_action filters.
    #
    # @example Basic usage
    #   chain = Chain.new([LoggingMiddleware, AuthMiddleware])
    #   chain.call(context) do
    #     # Handler code runs after all middleware have yielded
    #   end
    class Chain
      # Creates a new middleware chain
      #
      # @param middleware_classes [Array<Class>] Array of middleware classes to instantiate and run
      def initialize(middleware_classes)
        @middleware_classes = middleware_classes
      end

      # Executes the middleware chain
      #
      # Each middleware is instantiated and called in order. The provided
      # block is called after all middleware have yielded. Middleware can
      # stop the chain by not yielding.
      #
      # @param context [BoltRb::Context] The request context
      # @yield The handler to run after middleware processing
      # @return [void]
      def call(context, &block)
        chain = @middleware_classes.map(&:new)
        run_chain(chain, context, &block)
      end

      private

      # Recursively runs through the middleware chain
      #
      # @param chain [Array<Base>] Remaining middleware instances
      # @param context [BoltRb::Context] The request context
      # @yield The handler to run when chain is empty
      # @return [void]
      def run_chain(chain, context, &block)
        if chain.empty?
          block.call
        else
          middleware = chain.shift
          middleware.call(context) do
            run_chain(chain, context, &block)
          end
        end
      end
    end
  end
end
