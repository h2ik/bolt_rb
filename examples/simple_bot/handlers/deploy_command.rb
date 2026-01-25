# frozen_string_literal: true

class DeployCommand < BoltRb::CommandHandler
  command '/deploy'

  def handle
    ack "Deploying #{command_text}..."

    # Simulate deploy
    sleep 1

    say "Deployed #{command_text} successfully!"
  end
end
