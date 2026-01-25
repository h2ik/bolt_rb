# frozen_string_literal: true

module BoltRb
  module Middleware
    # Base class for all middleware
    #
    # Middleware classes should inherit from this and override #call
    # to implement custom behavior. The default implementation simply
    # yields to the next middleware in the chain.
    #
    # @example Custom middleware
    #   class AuthMiddleware < BoltRb::Middleware::Base
    #     def call(context)
    #       if authorized?(context)
    #         yield if block_given?
    #       else
    #         context.respond("Unauthorized")
    #       end
    #     end
    #   end
    class Base
      # Processes the request through this middleware
      #
      # Override this method in subclasses to add custom behavior.
      # Always call yield to continue the middleware chain.
      #
      # @param context [BoltRb::Context] The request context
      # @yield Continues to the next middleware in the chain
      # @return [void]
      def call(context)
        yield if block_given?
      end
    end
  end
end
