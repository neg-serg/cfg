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

# Link both channels — do NOT exit on individual failure so both get attempted
LINK_OK=true
for attempt in $(seq 1 5); do
    if pw-link "${NULL_SINK}:monitor_FL" "${RME_OUT}:playback_AUX${TARGET_LEFT}" 2>/dev/null; then
        debug "Linked left"
        break
    fi
    log "Retry $attempt: left"
    sleep 1
done || LINK_OK=false

for attempt in $(seq 1 5); do
    if pw-link "${NULL_SINK}:monitor_FR" "${RME_OUT}:playback_AUX${TARGET_RIGHT}" 2>/dev/null; then
        debug "Linked right"
        break
    fi
    log "Retry $attempt: right"
    sleep 1
done || LINK_OK=false

$LINK_OK || log "WARNING: one or both links failed"

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
