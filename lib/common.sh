#!/bin/bash
# Claude Code Notification Plugin - Common Functions
# https://github.com/anthropics/claude-code

_COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_COMMON_BASE_DIR="$(dirname "$_COMMON_SCRIPT_DIR")"
CONFIG_FILE="${CLAUDE_NOTIFICATION_CONFIG:-$_COMMON_BASE_DIR/config.json}"

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found at $CONFIG_FILE" >&2
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed" >&2
        return 1
    fi
}

# Get config value
get_config() {
    local key="$1"
    local default="$2"
    local value

    value=$(jq -r "$key // empty" "$CONFIG_FILE" 2>/dev/null)

    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Check if a notification method is enabled
is_enabled() {
    local method="$1"
    local enabled

    enabled=$(get_config ".${method}.enabled" "false")
    [[ "$enabled" == "true" ]]
}

# Log message
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local log_file
    log_file=$(get_config ".log_file" "")

    if [[ -n "$log_file" ]]; then
        echo "[$timestamp] [$level] $message" >> "$log_file"
    fi
}

# Parse Claude hook event from stdin
parse_hook_event() {
    local event_json
    event_json=$(cat)

    if [[ -z "$event_json" ]]; then
        return 1
    fi

    echo "$event_json"
}

# Get event type from hook event
get_event_type() {
    local event_json="$1"
    echo "$event_json" | jq -r '.hook_type // .event // "unknown"' 2>/dev/null
}

# Get tool name from PreToolUse event
get_tool_name() {
    local event_json="$1"
    echo "$event_json" | jq -r '.tool_name // "unknown"' 2>/dev/null
}

# Get tool input from PreToolUse event
get_tool_input() {
    local event_json="$1"
    echo "$event_json" | jq -r '.tool_input // {}' 2>/dev/null
}

# Format notification message based on event type
format_message() {
    local event_type="$1"
    local event_json="$2"
    local message=""

    # Get session info from event or environment
    local session_id=""
    local working_dir=""

    if [[ -n "$event_json" ]]; then
        session_id=$(echo "$event_json" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)
        working_dir=$(echo "$event_json" | jq -r '.working_directory // .cwd // empty' 2>/dev/null)
    fi

    # Fallback to environment variables
    [[ -z "$working_dir" ]] && working_dir="${PWD:-unknown}"

    # Get project name from working directory
    local project_name
    project_name=$(basename "$working_dir")

    case "$event_type" in
        "Notification")
            local notification_message
            notification_message=$(echo "$event_json" | jq -r '.message // "Claude Code needs your attention"' 2>/dev/null)
            message="[$project_name] $notification_message"
            ;;
        "Stop")
            local stop_reason
            stop_reason=$(echo "$event_json" | jq -r '.stop_reason // "Task completed"' 2>/dev/null)
            message="[$project_name] Claude Code stopped: $stop_reason"
            ;;
        "PreToolUse")
            local tool_name
            tool_name=$(get_tool_name "$event_json")
            local tool_input
            tool_input=$(get_tool_input "$event_json")

            case "$tool_name" in
                "Bash")
                    local command
                    command=$(echo "$tool_input" | jq -r '.command // "unknown command"' 2>/dev/null | head -c 100)
                    message="[$project_name] Bash: $command"
                    ;;
                "Write"|"Edit"|"NotebookEdit")
                    local file_path
                    file_path=$(echo "$tool_input" | jq -r '.file_path // .notebook_path // "unknown file"' 2>/dev/null)
                    message="[$project_name] $tool_name: $file_path"
                    ;;
                "Task")
                    local task_desc
                    task_desc=$(echo "$tool_input" | jq -r '.description // .prompt // "unknown task"' 2>/dev/null | head -c 80)
                    message="[$project_name] Task: $task_desc"
                    ;;
                "WebFetch")
                    local url
                    url=$(echo "$tool_input" | jq -r '.url // "unknown url"' 2>/dev/null | head -c 80)
                    message="[$project_name] WebFetch: $url"
                    ;;
                "WebSearch")
                    local query
                    query=$(echo "$tool_input" | jq -r '.query // "unknown query"' 2>/dev/null | head -c 80)
                    message="[$project_name] WebSearch: $query"
                    ;;
                *)
                    message="[$project_name] Tool: $tool_name"
                    ;;
            esac
            ;;
        *)
            message="[$project_name] Claude Code event: $event_type"
            ;;
    esac

    # Add working directory info
    message="$message\n📁 $working_dir"

    echo "$message"
}

# Get notification title based on event type
get_title() {
    local event_type="$1"
    local event_json="${2:-}"
    local title=""

    # Get workspace name
    local working_dir=""
    if [[ -n "$event_json" ]]; then
        working_dir=$(echo "$event_json" | jq -r '.working_directory // .cwd // empty' 2>/dev/null)
    fi
    [[ -z "$working_dir" ]] && working_dir="${PWD:-unknown}"
    local project_name
    project_name=$(basename "$working_dir")

    case "$event_type" in
        "Notification")
            title="Claude [$project_name] Notification"
            ;;
        "Stop")
            title="Claude [$project_name] Stopped"
            ;;
        "PreToolUse")
            title="Claude [$project_name] Approval"
            ;;
        *)
            title="Claude [$project_name]"
            ;;
    esac

    echo "$title"
}

# Get notification urgency based on event type
get_urgency() {
    local event_type="$1"

    case "$event_type" in
        "PreToolUse")
            echo "critical"
            ;;
        "Stop")
            echo "normal"
            ;;
        *)
            echo "normal"
            ;;
    esac
}

# Check if smart notify is enabled
is_smart_notify_enabled() {
    local enabled
    enabled=$(get_config ".smart_notify.enabled" "true")
    [[ "$enabled" == "true" ]]
}

# Check if a command matches a permission rule
# Rule format: ToolName(pattern:*)
match_permission_rule() {
    local tool_name="$1"
    local tool_input="$2"
    local rule="$3"

    # Parse rule: ToolName(pattern:*)
    local rule_tool rule_pattern
    if [[ "$rule" =~ ^([A-Za-z]+)\((.+):\*\)$ ]]; then
        rule_tool="${BASH_REMATCH[1]}"
        rule_pattern="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    # Check tool type matches
    [[ "$tool_name" != "$rule_tool" ]] && return 1

    # Check pattern based on tool type
    case "$tool_name" in
        "Bash")
            local command
            command=$(echo "$tool_input" | jq -r '.command // ""' 2>/dev/null)
            [[ "$command" == "$rule_pattern"* ]] && return 0
            ;;
        "Write"|"Edit"|"Read"|"NotebookEdit")
            local file_path
            file_path=$(echo "$tool_input" | jq -r '.file_path // .notebook_path // ""' 2>/dev/null)
            [[ "$file_path" == "$rule_pattern"* ]] && return 0
            ;;
    esac

    return 1
}

# Check if the tool call is auto-approved by Claude Code
is_auto_approved() {
    local event_type="$1"
    local event_json="$2"

    # Only applies to PreToolUse events
    [[ "$event_type" != "PreToolUse" ]] && return 1

    local tool_name tool_input working_dir
    tool_name=$(get_tool_name "$event_json")
    tool_input=$(get_tool_input "$event_json")
    working_dir=$(echo "$event_json" | jq -r '.working_directory // .cwd // ""' 2>/dev/null)

    # Check both project-level and global settings
    local settings_files=(
        "$working_dir/.claude/settings.local.json"
        "$HOME/.claude/settings.local.json"
    )

    for settings_file in "${settings_files[@]}"; do
        [[ ! -f "$settings_file" ]] && continue

        local rules
        rules=$(jq -r '.permissions.allow[]? // empty' "$settings_file" 2>/dev/null)

        while IFS= read -r rule; do
            [[ -z "$rule" ]] && continue
            if match_permission_rule "$tool_name" "$tool_input" "$rule"; then
                return 0
            fi
        done <<< "$rules"
    done

    return 1
}
