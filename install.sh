#!/bin/bash
# Claude Code Notification Plugin - Installation Script
#
# This script installs the notification plugin to ~/.claude/notifications/
# and helps configure Claude Code hooks.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.claude/notifications"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         Claude Code Notification Plugin Installer           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}→${NC} $1"
}

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install them with:"

        case "$(uname -s)" in
            Linux*)
                if command -v apt-get &>/dev/null; then
                    echo "  sudo apt-get install ${missing[*]}"
                elif command -v dnf &>/dev/null; then
                    echo "  sudo dnf install ${missing[*]}"
                elif command -v pacman &>/dev/null; then
                    echo "  sudo pacman -S ${missing[*]}"
                else
                    echo "  Use your package manager to install: ${missing[*]}"
                fi
                ;;
            Darwin*)
                echo "  brew install ${missing[*]}"
                ;;
        esac
        echo ""
        return 1
    fi

    return 0
}

# Check for Linux notification support
check_linux_notifications() {
    if [[ "$(uname -s)" == "Linux" ]]; then
        if ! command -v notify-send &>/dev/null; then
            print_warning "notify-send not found. Desktop notifications may not work."
            echo "  Install with: sudo apt-get install libnotify-bin"
        fi
    fi
}

# Install the plugin
install_plugin() {
    print_info "Installing plugin to $INSTALL_DIR"

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Copy files
    cp -r "$SCRIPT_DIR/notify.sh" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"

    # Copy config only if it doesn't exist
    if [[ ! -f "$INSTALL_DIR/config.json" ]]; then
        cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
        print_success "Created config.json"
    else
        print_info "Keeping existing config.json"
    fi

    # Make scripts executable
    chmod +x "$INSTALL_DIR/notify.sh"
    chmod +x "$INSTALL_DIR/lib/"*.sh

    print_success "Plugin files installed"
}

# Configure Claude hooks
configure_hooks() {
    print_info "Configuring Claude Code hooks"

    # Create .claude directory if needed
    mkdir -p "${HOME}/.claude"

    local hooks_config
    hooks_config=$(cat <<'EOF'
{
  "Notification": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/notifications/notify.sh Notification"
        }
      ]
    }
  ],
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/notifications/notify.sh Stop"
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/notifications/notify.sh PreToolUse"
        }
      ]
    }
  ]
}
EOF
)

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Merge with existing settings
        local existing_hooks
        existing_hooks=$(jq '.hooks // {}' "$CLAUDE_SETTINGS" 2>/dev/null || echo '{}')

        if [[ "$existing_hooks" != "{}" ]]; then
            print_warning "Existing hooks found in settings.json"
            echo ""
            echo "Would you like to:"
            echo "  1) Merge hooks (add notification hooks alongside existing)"
            echo "  2) Replace hooks (overwrite with notification hooks only)"
            echo "  3) Skip (don't modify hooks)"
            echo ""
            read -rp "Choice [1/2/3]: " choice

            case "$choice" in
                1)
                    # Merge hooks
                    local merged
                    merged=$(echo "$existing_hooks" | jq --argjson new "$hooks_config" '. * $new')
                    local updated
                    updated=$(jq --argjson hooks "$merged" '.hooks = $hooks' "$CLAUDE_SETTINGS")
                    echo "$updated" > "$CLAUDE_SETTINGS"
                    print_success "Hooks merged"
                    ;;
                2)
                    # Replace hooks
                    local updated
                    updated=$(jq --argjson hooks "$hooks_config" '.hooks = $hooks' "$CLAUDE_SETTINGS")
                    echo "$updated" > "$CLAUDE_SETTINGS"
                    print_success "Hooks replaced"
                    ;;
                *)
                    print_info "Skipping hooks configuration"
                    return 0
                    ;;
            esac
        else
            # No existing hooks, just add
            local updated
            updated=$(jq --argjson hooks "$hooks_config" '.hooks = $hooks' "$CLAUDE_SETTINGS")
            echo "$updated" > "$CLAUDE_SETTINGS"
            print_success "Hooks configured"
        fi
    else
        # Create new settings file
        echo "{\"hooks\": $hooks_config}" | jq '.' > "$CLAUDE_SETTINGS"
        print_success "Created settings.json with hooks"
    fi
}

# Test notification
test_notification() {
    echo ""
    read -rp "Would you like to send a test notification? [y/N]: " test_choice

    if [[ "$test_choice" =~ ^[Yy]$ ]]; then
        print_info "Sending test notification..."

        # Create a test event
        echo '{"message": "Test notification from installer"}' | \
            "$INSTALL_DIR/notify.sh" Notification

        print_success "Test notification sent!"
        echo "  If you didn't see it, check your config.json settings."
    fi
}

# Print configuration guide
print_config_guide() {
    echo ""
    echo -e "${BLUE}Configuration Guide${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    echo "Edit $INSTALL_DIR/config.json to customize:"
    echo ""
    echo "  Desktop notifications:"
    echo "    - enabled: true/false"
    echo "    - timeout: notification duration in milliseconds"
    echo ""
    echo "  Webhook (Slack/Discord/Telegram/WeCom/DingTalk/Feishu):"
    echo "    - enabled: true/false"
    echo "    - type: slack, discord, telegram, wecom, dingtalk, feishu, generic"
    echo "    - url: your webhook URL"
    echo ""
    echo "  Sound:"
    echo "    - enabled: true/false"
    echo "    - file: custom sound file path"
    echo ""
}

# Uninstall function
uninstall() {
    print_info "Uninstalling notification plugin..."

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
    fi

    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        # Remove hooks from settings
        local updated
        updated=$(jq 'del(.hooks.Notification) | del(.hooks.Stop) | del(.hooks.PreToolUse)' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [[ -n "$updated" ]]; then
            echo "$updated" > "$CLAUDE_SETTINGS"
            print_success "Removed notification hooks from settings"
        fi
    fi

    print_success "Uninstall complete"
}

# Main
main() {
    print_header

    case "${1:-install}" in
        install)
            if ! check_dependencies; then
                exit 1
            fi
            check_linux_notifications
            install_plugin
            configure_hooks
            test_notification
            print_config_guide
            echo ""
            print_success "Installation complete!"
            ;;
        uninstall)
            uninstall
            ;;
        *)
            echo "Usage: install.sh [install|uninstall]"
            exit 1
            ;;
    esac
}

main "$@"
