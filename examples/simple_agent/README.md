# Simple Agent

A minimal Slack AI assistant built with bolt-rb. It answers three fixed
questions and echoes everything else. Swap the canned replies for an LLM
call to make it useful.

## Setup

1. Create a Slack app at [api.slack.com/apps](https://api.slack.com/apps).
2. Select **From a manifest** and paste the contents of `manifest.json`.
3. Under **Basic Information**, create an app-level token with the
   `connections:write` scope. This is `SLACK_APP_TOKEN`.
4. Install the app to your workspace. Copy the bot token. This is
   `SLACK_BOT_TOKEN`.

## Run

```bash
bundle install
SLACK_BOT_TOKEN=xoxb-... SLACK_APP_TOKEN=xapp-... ruby agent.rb
```

Open Slack, click the assistant icon in the top bar, and pick **Simple
Agent**. A new thread starts and the assistant sends suggested prompts.

## What to look at

- `handlers/support_assistant.rb` shows the three lifecycle hooks:
  `thread_started`, `context_changed`, and `user_message`.
- `manifest.json` lists the scopes and events an assistant app must have.
  The **Agents & AI Apps** feature is enabled by the `assistant_view`
  block.
