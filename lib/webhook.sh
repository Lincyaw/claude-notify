#!/bin/bash
# Claude Code Notification Plugin - Webhook Notification Module
# Note: common.sh must be sourced before this file

# Send webhook notification
send_webhook_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    local webhook_url
    webhook_url=$(get_config ".webhook.url" "")

    if [[ -z "$webhook_url" ]]; then
        log "ERROR" "Webhook URL not configured"
        return 1
    fi

    local webhook_type
    webhook_type=$(get_config ".webhook.type" "generic")

    case "$webhook_type" in
        "slack")
            send_slack_webhook "$webhook_url" "$title" "$message" "$urgency"
            ;;
        "discord")
            send_discord_webhook "$webhook_url" "$title" "$message" "$urgency"
            ;;
        "telegram")
            send_telegram_webhook "$title" "$message"
            ;;
        "wecom"|"wechat_work")
            send_wecom_webhook "$webhook_url" "$title" "$message"
            ;;
        "dingtalk")
            send_dingtalk_webhook "$webhook_url" "$title" "$message"
            ;;
        "feishu"|"lark")
            send_feishu_webhook "$webhook_url" "$title" "$message"
            ;;
        "generic"|*)
            send_generic_webhook "$webhook_url" "$title" "$message" "$urgency"
            ;;
    esac
}

# Slack webhook
send_slack_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"
    local urgency="$4"

    local color="#36a64f"
    [[ "$urgency" == "critical" ]] && color="#ff0000"

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg message "$message" \
        --arg color "$color" \
        '{
            attachments: [{
                color: $color,
                title: $title,
                text: $message,
                footer: "Claude Code Notification",
                ts: (now | floor)
            }]
        }')

    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" &>/dev/null
    log "INFO" "Slack notification sent: $title"
}

# Discord webhook
send_discord_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"
    local urgency="$4"

    local color=3066993
    [[ "$urgency" == "critical" ]] && color=15158332

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg message "$message" \
        --argjson color "$color" \
        '{
            embeds: [{
                title: $title,
                description: $message,
                color: $color,
                footer: {
                    text: "Claude Code Notification"
                }
            }]
        }')

    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" &>/dev/null
    log "INFO" "Discord notification sent: $title"
}

# Telegram webhook
send_telegram_webhook() {
    local title="$1"
    local message="$2"

    local bot_token
    bot_token=$(get_config ".webhook.telegram_bot_token" "")
    local chat_id
    chat_id=$(get_config ".webhook.telegram_chat_id" "")

    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        log "ERROR" "Telegram bot_token or chat_id not configured"
        return 1
    fi

    local text="*${title}*\n${message}"
    local url="https://api.telegram.org/bot${bot_token}/sendMessage"

    curl -s -X POST "$url" \
        -d chat_id="$chat_id" \
        -d text="$text" \
        -d parse_mode="Markdown" &>/dev/null

    log "INFO" "Telegram notification sent: $title"
}

# WeCom (Enterprise WeChat) webhook
send_wecom_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg message "$message" \
        '{
            msgtype: "markdown",
            markdown: {
                content: ("# \($title)\n\($message)")
            }
        }')

    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" &>/dev/null
    log "INFO" "WeCom notification sent: $title"
}

# DingTalk webhook
send_dingtalk_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg message "$message" \
        '{
            msgtype: "markdown",
            markdown: {
                title: $title,
                text: ("## \($title)\n\($message)")
            }
        }')

    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" &>/dev/null
    log "INFO" "DingTalk notification sent: $title"
}

# Feishu (Lark) webhook
send_feishu_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"
    local urgency="${4:-normal}"

    # Parse message to extract components
    # Expected format: "[project] action: detail\n📁 path"
    local project_name=""
    local action_detail=""
    local working_dir=""

    # Extract project name from [project]
    if [[ "$message" =~ ^\[([^\]]+)\] ]]; then
        project_name="${BASH_REMATCH[1]}"
    fi

    # Extract working directory
    if [[ "$message" =~ 📁[[:space:]]*(.*) ]]; then
        working_dir="${BASH_REMATCH[1]}"
    fi

    # Extract action detail (everything between ] and \n📁)
    action_detail=$(echo "$message" | sed -n 's/^\[[^]]*\] *//p' | sed 's/\\n📁.*//' | head -1)

    # Determine header color based on urgency/event type
    local header_template="blue"
    if [[ "$title" == *"Approval"* ]]; then
        header_template="orange"
    elif [[ "$title" == *"Stopped"* ]]; then
        header_template="green"
    fi

    # Build rich card content with actual newlines
    local content
    content="**📋 ${action_detail}**"
    if [[ -n "$working_dir" ]]; then
        content="${content}"$'\n\n'"📁 \`${working_dir}\`"
    fi

    local payload
    payload=$(jq -n \
        --arg title "$title" \
        --arg content "$content" \
        --arg template "$header_template" \
        '{
            msg_type: "interactive",
            card: {
                header: {
                    title: {
                        tag: "plain_text",
                        content: $title
                    },
                    template: $template
                },
                elements: [
                    {
                        tag: "div",
                        text: {
                            tag: "lark_md",
                            content: $content
                        }
                    }
                ]
            }
        }')

    curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$url" &>/dev/null
    log "INFO" "Feishu notification sent: $title"
}

# Generic webhook (customizable)
send_generic_webhook() {
    local url="$1"
    local title="$2"
    local message="$3"
    local urgency="$4"

    local method
    method=$(get_config ".webhook.method" "POST")

    local content_type
    content_type=$(get_config ".webhook.content_type" "application/json")

    # Get custom template or use default
    local template
    template=$(get_config ".webhook.template" "")

    local payload
    if [[ -n "$template" ]]; then
        # Use custom template with variable substitution
        payload=$(echo "$template" | \
            sed "s/{{title}}/$title/g" | \
            sed "s/{{message}}/$message/g" | \
            sed "s/{{urgency}}/$urgency/g")
    else
        # Default JSON payload
        payload=$(jq -n \
            --arg title "$title" \
            --arg message "$message" \
            --arg urgency "$urgency" \
            '{
                title: $title,
                message: $message,
                urgency: $urgency,
                source: "claude-code",
                timestamp: (now | floor)
            }')
    fi

    # Get custom headers
    local headers=""
    local custom_headers
    custom_headers=$(get_config ".webhook.headers" "{}")

    if [[ "$custom_headers" != "{}" && "$custom_headers" != "null" ]]; then
        while IFS="=" read -r key value; do
            headers="$headers -H \"$key: $value\""
        done < <(echo "$custom_headers" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')
    fi

    eval "curl -s -X $method -H 'Content-Type: $content_type' $headers -d '$payload' '$url'" &>/dev/null
    log "INFO" "Generic webhook notification sent: $title"
}
