# Claude Code Notification Plugin

Get notified when Claude Code needs your attention! This plugin sends notifications through multiple channels when Claude Code requires approval or completes a task.

## Features

- **Desktop Notifications** - Native notifications on Linux, macOS, and Windows
- **Webhook Support** - Send to Slack, Discord, Telegram, WeCom, DingTalk, Feishu, or any custom webhook
- **Sound Alerts** - Audio notifications with customizable sounds
- **Cross-Platform** - Works on Linux, macOS, and Windows

## Installation

### Quick Install

```bash
./install.sh
```

The installer will:
1. Copy plugin files to `~/.claude/notifications/`
2. Configure Claude Code hooks
3. Optionally send a test notification

### Manual Install

1. Copy the `notification` folder to `~/.claude/notifications/`
2. Make scripts executable: `chmod +x ~/.claude/notifications/*.sh ~/.claude/notifications/lib/*.sh`
3. Add hooks to your `~/.claude/settings.json` (see `hooks-example.json`)

## Configuration

Edit `~/.claude/notifications/config.json`:

> **Note**: Only Feishu (Lark) webhook has been tested. Other notification methods (Slack, Discord, Telegram, WeCom, DingTalk, Desktop, Sound) are implemented but not tested.

### Webhook URL Configuration (Recommended: Environment Variable)

For security, it's recommended to set the webhook URL via environment variable instead of storing it in config files:

```bash
# Add to your ~/.bashrc or ~/.zshrc
export CLAUDE_NOTIFICATION_WEBHOOK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/your-actual-hook-id"
```

The priority order is: **Environment variable > config.json**

### Webhook (Feishu / Lark) - Tested

```json
{
  "webhook": {
    "enabled": true,
    "type": "feishu"
  }
}
```

### Other Webhook Types (Not Tested)

The following webhook types are supported but have not been tested:

- **Slack**: `"type": "slack"`, `"url": "https://hooks.slack.com/services/..."`
- **Discord**: `"type": "discord"`, `"url": "https://discord.com/api/webhooks/..."`
- **Telegram**: `"type": "telegram"`, requires `telegram_bot_token` and `telegram_chat_id`
- **WeCom**: `"type": "wecom"`, `"url": "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=..."`
- **DingTalk**: `"type": "dingtalk"`, `"url": "https://oapi.dingtalk.com/robot/send?access_token=..."`
- **Generic**: `"type": "generic"`, custom webhook with configurable `method`, `headers`, and `template`

### Desktop Notifications (Not Tested)

```json
{
  "desktop": {
    "enabled": true,
    "icon": "dialog-information",
    "timeout": 10000
  }
}
```

### Sound Alerts (Not Tested)

```json
{
  "sound": {
    "enabled": true,
    "file": "/path/to/custom/sound.wav",
    "critical_file": "/path/to/urgent/sound.wav",
    "bell_repeat": 2
  }
}
```

## Hook Events

| Event | When it triggers |
|-------|-----------------|
| `Notification` | Claude Code sends a notification |
| `Stop` | Claude Code stops/completes |
| `PreToolUse` | Before executing a tool (Bash, Write, Edit, etc.) |

## Dependencies

- `jq` - JSON processor (required)
- `curl` - For webhook notifications
- `notify-send` - For Linux desktop notifications (libnotify)
- `paplay`/`aplay`/`ffplay`/`mpv` - For sound playback on Linux

### Install on Ubuntu/Debian

```bash
sudo apt-get install jq curl libnotify-bin pulseaudio-utils
```

### Install on macOS

```bash
brew install jq curl
```

## Uninstall

```bash
./install.sh uninstall
```

## Troubleshooting

### No desktop notification on Linux
- Install libnotify: `sudo apt-get install libnotify-bin`
- Ensure you have a notification daemon running

### No sound
- Install an audio player: `sudo apt-get install pulseaudio-utils`
- Check your system volume

### Webhook not working
- Verify your webhook URL is correct
- Check the log file (set `log_file` in config.json)
- Test with curl manually

## License

MIT License
