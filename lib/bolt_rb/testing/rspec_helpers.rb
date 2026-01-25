# frozen_string_literal: true

module BoltRb
  module Testing
    # RSpec helper methods for testing Bolt handlers
    #
    # Include this module in your RSpec configuration to get convenient
    # methods for building contexts and mocking Slack clients.
    #
    # @example Including in RSpec
    #   RSpec.configure do |config|
    #     config.include BoltRb::Testing::RSpecHelpers
    #   end
    #
    # @example Using in specs
    #   describe MyHandler do
    #     it 'handles messages' do
    #       ctx = build_context(payload.message(text: 'hello'))
    #       MyHandler.call(ctx)
    #       expect(ctx.acked?).to be true
    #     end
    #   end
    module RSpecHelpers
      # Builds a Context object from a payload for testing
      #
      # @param payload [Hash] The Slack event payload
      # @param client [Object, nil] The Slack client (mocked if nil)
      # @param ack [Proc, nil] The acknowledgement function (no-op if nil)
      # @return [BoltRb::Context] The context object
      def build_context(payload, client: nil, ack: nil)
        BoltRb::Context.new(
          payload: payload,
          client: client || mock_slack_client,
          ack: ack || ->(_) {}
        )
      end

      # Creates a mock Slack Web API client with common methods stubbed
      #
      # @return [RSpec::Mocks::Double] A mock Slack client
      def mock_slack_client
        client = instance_double(Slack::Web::Client)
        allow(client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '123.456' })
        allow(client).to receive(:chat_update).and_return({ 'ok' => true })
        allow(client).to receive(:views_open).and_return({ 'ok' => true })
        allow(client).to receive(:views_update).and_return({ 'ok' => true })
        client
      end

      # Convenience accessor for the PayloadFactory
      #
      # @return [Class] The PayloadFactory class
      #
      # @example
      #   payload.message(text: 'hello')
      #   payload.command(command: '/deploy')
      def payload
        BoltRb::Testing::PayloadFactory
      end
    end
  end
end
