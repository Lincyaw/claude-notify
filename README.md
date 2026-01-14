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

### Desktop Notifications

```json
{
  "desktop": {
    "enabled": true,
    "icon": "dialog-information",
    "timeout": 10000
  }
}
```

### Webhook (Slack)

```json
{
  "webhook": {
    "enabled": true,
    "type": "slack",
    "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }
}
```

### Webhook (Discord)

```json
{
  "webhook": {
    "enabled": true,
    "type": "discord",
    "url": "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
  }
}
```

### Webhook (Telegram)

```json
{
  "webhook": {
    "enabled": true,
    "type": "telegram",
    "telegram_bot_token": "YOUR_BOT_TOKEN",
    "telegram_chat_id": "YOUR_CHAT_ID"
  }
}
```

### Webhook (WeCom / Enterprise WeChat)

```json
{
  "webhook": {
    "enabled": true,
    "type": "wecom",
    "url": "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_KEY"
  }
}
```

### Webhook (DingTalk)

```json
{
  "webhook": {
    "enabled": true,
    "type": "dingtalk",
    "url": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  }
}
```

### Webhook (Feishu / Lark)

```json
{
  "webhook": {
    "enabled": true,
    "type": "feishu",
    "url": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_HOOK_ID"
  }
}
```

### Sound Alerts

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

### Custom Webhook

```json
{
  "webhook": {
    "enabled": true,
    "type": "generic",
    "url": "https://your-api.example.com/notify",
    "method": "POST",
    "content_type": "application/json",
    "headers": {
      "Authorization": "Bearer YOUR_TOKEN"
    },
    "template": "{\"text\": \"{{title}}: {{message}}\"}"
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
