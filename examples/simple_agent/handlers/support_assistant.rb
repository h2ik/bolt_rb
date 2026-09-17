# frozen_string_literal: true

# A small assistant that answers a few fixed questions.
#
# Replace the body of #user_message with a call to your LLM of choice.
# The rest of the class shows the full assistant thread lifecycle.
class SupportAssistant < BoltRb::AssistantHandler
  PROMPTS = [
    { title: 'What can you do?', message: 'help' },
    { title: 'Where am I?', message: 'where am i' },
    { title: 'Tell me a joke', message: 'joke' }
  ].freeze

  # Slack opened a new assistant thread for the user
  def thread_started
    say "Hi <@#{user}>! I am a demo assistant built with bolt-rb."
    set_suggested_prompts(PROMPTS, title: 'Try one of these')
  end

  # The user switched channels while the thread stayed open
  def context_changed
    channel_id = thread_context&.dig('channel_id')
    say "I see you moved to <##{channel_id}>." if channel_id
  end

  # The user sent a message in the thread
  def user_message
    set_status 'is thinking...'
    set_title text[0, 50]

    say reply_for(text)
  end

  private

  # Pick a canned reply for the message text
  #
  # @param message [String]
  # @return [String]
  def reply_for(message)
    case message.to_s.downcase.strip
    when 'help'
      'I can echo your messages, tell you which channel you are viewing, and tell one joke.'
    when 'where am i'
      channel_id = thread_context&.dig('channel_id')
      channel_id ? "You are looking at <##{channel_id}>." : 'I do not know which channel you are viewing yet.'
    when 'joke'
      'Why do Ruby developers never get lost? They always have a Gemfile.lock.'
    else
      "You said: #{message}"
    end
  end
end
