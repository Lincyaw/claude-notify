#!/bin/bash
# Claude Code Notification Plugin - Desktop Notification Module
# Note: common.sh must be sourced before this file

# Send desktop notification
send_desktop_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-dialog-information}"

    # Get custom icon from config
    local custom_icon
    custom_icon=$(get_config ".desktop.icon" "")
    if [[ -n "$custom_icon" ]]; then
        icon="$custom_icon"
    fi

    # Get timeout from config (in milliseconds)
    local timeout
    timeout=$(get_config ".desktop.timeout" "5000")

    # Detect OS and send notification
    case "$(uname -s)" in
        Linux*)
            send_linux_notification "$title" "$message" "$urgency" "$icon" "$timeout"
            ;;
        Darwin*)
            send_macos_notification "$title" "$message"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            send_windows_notification "$title" "$message"
            ;;
        *)
            log "ERROR" "Unsupported OS for desktop notifications"
            return 1
            ;;
    esac
}

# Linux notification using notify-send
send_linux_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"
    local icon="$4"
    local timeout="$5"

    if command -v notify-send &>/dev/null; then
        notify-send \
            --urgency="$urgency" \
            --icon="$icon" \
            --expire-time="$timeout" \
            "$title" "$message"
        log "INFO" "Desktop notification sent: $title"
    else
        log "ERROR" "notify-send not found. Install libnotify-bin"
        return 1
    fi
}

# macOS notification using osascript
send_macos_notification() {
    local title="$1"
    local message="$2"

    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log "INFO" "macOS notification sent: $title"
    else
        log "ERROR" "Failed to send macOS notification"
        return 1
    fi
}

# Windows notification using PowerShell
send_windows_notification() {
    local title="$1"
    local message="$2"

    powershell.exe -Command "
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        \$template = @\"
        <toast>
            <visual>
                <binding template=\"ToastText02\">
                    <text id=\"1\">$title</text>
                    <text id=\"2\">$message</text>
                </binding>
            </visual>
        </toast>
\"@

        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        \$xml.LoadXml(\$template)
        \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
    " 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log "INFO" "Windows notification sent: $title"
    else
        log "ERROR" "Failed to send Windows notification"
        return 1
    fi
}
