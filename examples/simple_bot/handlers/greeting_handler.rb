# frozen_string_literal: true

class GreetingHandler < BoltRb::EventHandler
  listen_to :message, pattern: /hello/i

  def handle
    say "Hey there <@#{user}>! Welcome to bolt-rb."
  end
end
