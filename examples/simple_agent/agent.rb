#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'bolt_rb'

BoltRb.configure do |config|
  config.bot_token = ENV.fetch('SLACK_BOT_TOKEN')
  config.app_token = ENV.fetch('SLACK_APP_TOKEN')
  config.handler_paths = [File.expand_path('handlers', __dir__)]

  # Handlers run on this many threads. Each LLM call holds one thread
  # while it waits, so size this to the number of users you expect at once.
  config.worker_threads = 4
end

app = BoltRb::App.new

%w[INT TERM].each do |signal|
  Signal.trap(signal) do
    app.request_stop
  end
end

puts 'Starting agent...'
app.start
