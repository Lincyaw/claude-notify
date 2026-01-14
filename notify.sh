#!/bin/bash
# Claude Code Notification Plugin
# Send notifications when Claude Code needs your attention
#
# Usage: notify.sh <event_type>
#   event_type: Notification, Stop, PreToolUse, etc.
#
# The script reads event data from stdin (JSON format from Claude hooks)

set -euo pipefail

NOTIFY_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modules
source "$NOTIFY_BASE_DIR/lib/common.sh"
source "$NOTIFY_BASE_DIR/lib/desktop.sh"
source "$NOTIFY_BASE_DIR/lib/webhook.sh"
source "$NOTIFY_BASE_DIR/lib/sound.sh"

# Main entry point
main() {
    local event_type="${1:-}"

    if [[ -z "$event_type" ]]; then
        echo "Usage: notify.sh <event_type>" >&2
        echo "Event types: Notification, Stop, PreToolUse" >&2
        exit 1
    fi

    # Load configuration
    if ! load_config; then
        exit 1
    fi

    # Read event data from stdin
    local event_json=""
    if [[ ! -t 0 ]]; then
        event_json=$(parse_hook_event)
    fi

    # Format notification content
    local title
    title=$(get_title "$event_type" "$event_json")
    local message
    message=$(format_message "$event_type" "$event_json")
    local urgency
    urgency=$(get_urgency "$event_type")

    log "INFO" "Processing event: $event_type"

    # Send notifications based on enabled methods
    local sent=false

    # Desktop notification
    if is_enabled "desktop"; then
        send_desktop_notification "$title" "$message" "$urgency" && sent=true
    fi

    # Webhook notification
    if is_enabled "webhook"; then
        send_webhook_notification "$title" "$message" "$urgency" && sent=true
    fi

    # Sound notification
    if is_enabled "sound"; then
        play_notification_sound "$urgency" && sent=true
    fi

    if [[ "$sent" == "false" ]]; then
        log "WARN" "No notification methods enabled or all failed"
    fi
}

main "$@"
