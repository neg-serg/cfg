#!/usr/bin/env bash
# Game Audio Bridge: link game_output to RME AIO Pro, both channels
# Debug: set GAME_AUDIO_BRIDGE_DEBUG=1 for verbose logging
set -uo pipefail

NULL_SINK="game_output"
TARGET_LEFT=0
TARGET_RIGHT=1
LINK_TIMEOUT=20
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

log "Waiting for RME AIO Pro sink..."
RME_OUT=""
for i in $(seq 1 30); do
    RME_OUT="$(find_rme_sink)"
    [[ -n "$RME_OUT" ]] && break
    sleep 1
done
[[ -n "$RME_OUT" ]] || { log "ERROR: RME sink not found after 30s"; exit 1; }
log "RME sink: $RME_OUT"

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

log "Disconnecting existing links on target ports..."
pw-link -d "${NULL_SINK}:monitor_FL" "${RME_OUT}:playback_AUX${TARGET_LEFT}" 2>/dev/null || true
pw-link -d "${NULL_SINK}:monitor_FR" "${RME_OUT}:playback_AUX${TARGET_RIGHT}" 2>/dev/null || true

# Link both channels
link_target() {
    local port="$1" target="$2" attempt result
    for attempt in $(seq 1 5); do
        result=$(pw-link "${NULL_SINK}:${port}" "${RME_OUT}:${target}" 2>&1) && {
            log "Linked: ${NULL_SINK}:${port} -> ${RME_OUT}:${target}"
            return 0
        }
        if echo "$result" | grep -q "File exists"; then
            debug "Already linked: $port -> $target"
            return 0
        fi
        debug "Retry $attempt ($result): $port -> $target"
        sleep 1
    done
    log "ERROR: failed to link $port -> $target"
    return 1
}

LINK_OK=true
link_target "monitor_FL" "playback_AUX${TARGET_LEFT}" || LINK_OK=false
link_target "monitor_FR" "playback_AUX${TARGET_RIGHT}" || LINK_OK=false

if [ "$LINK_OK" = false ]; then
    log "ERROR: one or both links failed — not changing default sink"
    exit 1
fi

log "Setting default sink to $NULL_SINK..."
for i in $(seq 1 5); do
    if pactl set-default-sink "$NULL_SINK" 2>/dev/null; then
        log "Default sink set to $NULL_SINK"
        break
    fi
    sleep 1
done

CURRENT_DEFAULT=$(pactl info 2>/dev/null | awk '/Default Sink:/ {print $NF}')
log "Default sink: $CURRENT_DEFAULT"
log "Bridge complete"
