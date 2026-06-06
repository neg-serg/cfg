#!/usr/bin/env bash
# Game Audio Bridge daemon: link game_output to RME AIO Pro and maintain the link
# Debug: set GAME_AUDIO_BRIDGE_DEBUG=1 for verbose logging
set -uo pipefail

NULL_SINK="game_output"
TARGET_LEFT=0
TARGET_RIGHT=1
LINK_TIMEOUT=20
POLL_INTERVAL=5
LOG_PREFIX="game-audio-bridge"

log() { echo "$LOG_PREFIX: $*" >&2; }
debug() { [[ -n "${GAME_AUDIO_BRIDGE_DEBUG:-}" ]] && log "DEBUG: $*"; }

find_rme_sink() {
    pw-dump 2>/dev/null | python3 -c "
import json, sys
for obj in json.load(sys.stdin):
    props = obj.get('info', {}).get('props', {})
    nick = props.get('node.nick', '')
    name = props.get('node.name', '')
    if nick == 'RME AIO Pro' and 'alsa_output' in name:
        print(name)
        break
"
}

cleanup() {
    log "Shutting down, disconnecting links..."
    pw-link -d "${NULL_SINK}:monitor_FL" "${RME_OUT}:playback_AUX${TARGET_LEFT}" 2>/dev/null || true
    pw-link -d "${NULL_SINK}:monitor_FR" "${RME_OUT}:playback_AUX${TARGET_RIGHT}" 2>/dev/null || true
    pactl set-default-sink "${RME_OUT}" 2>/dev/null || true
    log "Cleanup done"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

links_ok() {
    pw-link -l 2>/dev/null | grep -q "^${NULL_SINK}:monitor_FL" || return 1
    pw-link -l 2>/dev/null | grep -q "^${NULL_SINK}:monitor_FR" || return 1
    return 0
}

ensure_links() {
    local linked=true
    pw-link "${NULL_SINK}:monitor_FL" "${RME_OUT}:playback_AUX${TARGET_LEFT}" 2>/dev/null || linked=false
    pw-link "${NULL_SINK}:monitor_FR" "${RME_OUT}:playback_AUX${TARGET_RIGHT}" 2>/dev/null || linked=false
    if [ "$linked" = true ]; then
        log "Links established: ${NULL_SINK}:monitor -> ${RME_OUT}:playback_AUX{${TARGET_LEFT},${TARGET_RIGHT}}"
        return 0
    fi
    # If "File exists" it actually succeeded, so check what failed
    if pw-link -l 2>/dev/null | grep -q "^${NULL_SINK}:monitor_FL"; then
        log "Link monitor_FL already exists"
    fi
    if pw-link -l 2>/dev/null | grep -q "^${NULL_SINK}:monitor_FR"; then
        log "Link monitor_FR already exists"
    fi
    return 0
}

ensure_default_sink() {
    local current
    current=$(pactl info 2>/dev/null | awk '/Default Sink:/ {print $NF}')
    if [ "$current" != "$NULL_SINK" ]; then
        if pactl set-default-sink "$NULL_SINK" 2>/dev/null; then
            log "Default sink restored to $NULL_SINK (was $current)"
        fi
    fi
}

# Find RME
log "Waiting for RME AIO Pro sink..."
RME_OUT=""
for i in $(seq 1 30); do
    RME_OUT="$(find_rme_sink)"
    [[ -n "$RME_OUT" ]] && break
    sleep 1
done
[[ -n "$RME_OUT" ]] || { log "ERROR: RME sink not found after 30s"; exit 1; }
log "RME sink: $RME_OUT"

# Wait for game_output
log "Waiting for $NULL_SINK null-sink..."
for i in $(seq 1 "$LINK_TIMEOUT"); do
    if pactl list short sinks 2>/dev/null | grep -q "$NULL_SINK"; then
        if pw-link -o 2>/dev/null | grep -q "${NULL_SINK}:monitor_FL" && \
           pw-link -o 2>/dev/null | grep -q "${NULL_SINK}:monitor_FR"; then
            log "$NULL_SINK ready"
            break
        fi
    fi
    sleep 1
done

# Initial link
ensure_links
ensure_default_sink

log "Bridge active, monitoring every ${POLL_INTERVAL}s..."
while true; do
    sleep "$POLL_INTERVAL"
    links_ok || ensure_links
    ensure_default_sink
done
