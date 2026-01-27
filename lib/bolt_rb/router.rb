# frozen_string_literal: true

module BoltRb
  # Router maintains a registry of handlers and routes incoming payloads
  # to the appropriate handlers based on their matching criteria.
  #
  # The router acts as the central dispatch mechanism for Bolt applications,
  # collecting registered handlers and determining which ones should process
  # a given Slack payload.
  #
  # @example Basic usage
  #   router = BoltRb::Router.new
  #
  #   router.register(MyMessageHandler)
  #   router.register(MyCommandHandler)
  #
  #   handlers = router.route(payload)
  #   handlers.each { |h| h.new(context).call }
  #
  # @example Using the global router
  #   BoltRb.router.register(MyHandler)
  #   BoltRb.router.route(payload)
  class Router
    # Creates a new Router instance with an empty handler registry
    def initialize
      @handlers = []
    end

    # Registers a handler class with the router
    #
    # The handler class should respond to .matches?(payload) to determine
    # if it should process a given payload. Duplicate registrations are ignored.
    #
    # @param handler_class [Class] A handler class (EventHandler, CommandHandler, etc.)
    # @return [void]
    #
    # @example
    #   router.register(MyMessageHandler)
    def register(handler_class)
      @handlers << handler_class unless @handlers.include?(handler_class)
    end

    # Routes a payload to all matching handlers
    #
    # Iterates through all registered handlers and returns those whose
    # .matches?(payload) method returns true.
    #
    # @param payload [Hash] The incoming Slack payload
    # @return [Array<Class>] Array of handler classes that match the payload
    #
    # @example
    #   payload = { 'event' => { 'type' => 'message', 'text' => 'hello' } }
    #   handlers = router.route(payload)
    #   # => [MessageHandler, HelloHandler]
    def route(payload)
      @handlers.select { |handler| handler.matches?(payload) }
    end

    # Returns the number of registered handlers
    #
    # @return [Integer] The count of registered handlers
    def handler_count
      @handlers.length
    end

    # Removes all registered handlers
    #
    # Useful for testing or reconfiguration scenarios.
    #
    # @return [void]
    def clear
      @handlers.clear
    end
  end
end
