# frozen_string_literal: true

require_relative 'testing/payload_factory'
require_relative 'testing/rspec_helpers'

module BoltRb
  # Testing utilities for BoltRb applications
  #
  # This module provides helpers for writing tests for Slack handlers,
  # including payload factories and RSpec integration.
  #
  # @example Basic setup in spec_helper.rb
  #   require 'bolt_rb/testing'
  #
  #   RSpec.configure do |config|
  #     config.include BoltRb::Testing::RSpecHelpers
  #   end
  module Testing
  end
end
