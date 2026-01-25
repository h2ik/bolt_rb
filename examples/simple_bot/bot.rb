#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'bolt_rb'

BoltRb.configure do |config|
  config.bot_token = ENV.fetch('SLACK_BOT_TOKEN')
  config.app_token = ENV.fetch('SLACK_APP_TOKEN')
  config.handler_paths = [File.expand_path('handlers', __dir__)]
end

app = BoltRb::App.new

%w[INT TERM].each do |signal|
  Signal.trap(signal) do
    puts "\nShutting down..."
    app.stop
    exit 0
  end
end

puts 'Starting bot...'
app.start
