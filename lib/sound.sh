#!/bin/bash
# Claude Code Notification Plugin - Sound Notification Module
# Note: common.sh must be sourced before this file

# Play notification sound
play_notification_sound() {
    local urgency="${1:-normal}"

    local sound_file
    sound_file=$(get_config ".sound.file" "")

    # Use different sounds for different urgency levels
    if [[ "$urgency" == "critical" ]]; then
        local critical_sound
        critical_sound=$(get_config ".sound.critical_file" "")
        if [[ -n "$critical_sound" && -f "$critical_sound" ]]; then
            sound_file="$critical_sound"
        fi
    fi

    # If no custom sound, try to use system sound
    if [[ -z "$sound_file" || ! -f "$sound_file" ]]; then
        sound_file=$(find_system_sound)
    fi

    if [[ -n "$sound_file" && -f "$sound_file" ]]; then
        play_sound_file "$sound_file"
    else
        # Fall back to terminal bell
        play_terminal_bell
    fi
}

# Find system notification sound
find_system_sound() {
    local sound_paths=(
        "/usr/share/sounds/freedesktop/stereo/message.oga"
        "/usr/share/sounds/freedesktop/stereo/complete.oga"
        "/usr/share/sounds/freedesktop/stereo/bell.oga"
        "/usr/share/sounds/gnome/default/alerts/drip.ogg"
        "/usr/share/sounds/ubuntu/stereo/message.ogg"
        "/System/Library/Sounds/Ping.aiff"
        "/System/Library/Sounds/Glass.aiff"
    )

    for path in "${sound_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Play sound file
play_sound_file() {
    local file="$1"

    case "$(uname -s)" in
        Linux*)
            play_linux_sound "$file"
            ;;
        Darwin*)
            play_macos_sound "$file"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            play_windows_sound "$file"
            ;;
        *)
            log "ERROR" "Unsupported OS for sound playback"
            play_terminal_bell
            ;;
    esac
}

# Linux sound playback
play_linux_sound() {
    local file="$1"

    if command -v paplay &>/dev/null; then
        paplay "$file" &>/dev/null &
        log "INFO" "Playing sound with paplay: $file"
    elif command -v aplay &>/dev/null; then
        aplay "$file" &>/dev/null &
        log "INFO" "Playing sound with aplay: $file"
    elif command -v ffplay &>/dev/null; then
        ffplay -nodisp -autoexit "$file" &>/dev/null &
        log "INFO" "Playing sound with ffplay: $file"
    elif command -v mpv &>/dev/null; then
        mpv --no-video --really-quiet "$file" &>/dev/null &
        log "INFO" "Playing sound with mpv: $file"
    else
        log "WARN" "No audio player found, using terminal bell"
        play_terminal_bell
    fi
}

# macOS sound playback
play_macos_sound() {
    local file="$1"

    if command -v afplay &>/dev/null; then
        afplay "$file" &>/dev/null &
        log "INFO" "Playing sound with afplay: $file"
    else
        play_terminal_bell
    fi
}

# Windows sound playback
play_windows_sound() {
    local file="$1"

    powershell.exe -Command "(New-Object Media.SoundPlayer '$file').PlaySync()" &>/dev/null &
    log "INFO" "Playing sound on Windows: $file"
}

# Terminal bell fallback
play_terminal_bell() {
    local repeat
    repeat=$(get_config ".sound.bell_repeat" "1")

    for ((i=0; i<repeat; i++)); do
        printf '\a'
        sleep 0.2
    done

    log "INFO" "Playing terminal bell"
}
