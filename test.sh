#!/bin/bash
# Test script for Claude Code Notification Plugin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing Claude Code Notification Plugin"
echo "========================================"
echo ""

# Test Notification event
echo "1. Testing Notification event..."
echo '{"message": "Test notification message", "hook_type": "Notification"}' | \
    "$SCRIPT_DIR/notify.sh" Notification
echo "   Done!"
echo ""

# Test Stop event
echo "2. Testing Stop event..."
echo '{"stop_reason": "Task completed successfully", "hook_type": "Stop"}' | \
    "$SCRIPT_DIR/notify.sh" Stop
echo "   Done!"
echo ""

# Test PreToolUse event (Bash)
echo "3. Testing PreToolUse (Bash) event..."
echo '{"hook_type": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "echo hello world"}}' | \
    "$SCRIPT_DIR/notify.sh" PreToolUse
echo "   Done!"
echo ""

echo "All tests completed!"
echo ""
echo "If you didn't receive any notifications, please check:"
echo "  1. Your config.json has at least one method enabled"
echo "  2. Required dependencies are installed (jq, notify-send, etc.)"
echo "  3. Webhook URLs are correctly configured"

echo ""
echo "========================================"
echo "Testing Smart Notify Feature"
echo "========================================"
echo ""

source "$SCRIPT_DIR/lib/common.sh"

# Test smart notify functions
echo "4. Testing match_permission_rule..."
tool_input='{"command": "uv run ruff check src/main.py"}'
if match_permission_rule "Bash" "$tool_input" "Bash(uv run ruff check:*)"; then
    echo "   PASS: Rule matching works"
else
    echo "   FAIL: Rule matching failed"
fi

echo ""
echo "5. Testing is_auto_approved..."
event_json='{"hook_type": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "npm install"}, "working_directory": "/tmp"}'
if is_auto_approved "PreToolUse" "$event_json"; then
    echo "   Result: Command is auto-approved (will skip notification)"
else
    echo "   Result: Command requires approval (will send notification)"
fi

echo ""
echo "Smart notify tests completed!"

