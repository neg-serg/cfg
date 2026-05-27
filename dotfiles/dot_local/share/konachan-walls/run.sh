#!/usr/bin/env bash
# konachan-walls launcher
# Usage: sk [target-dir]
#   target-dir: where to save wallpapers (default: ~/pic/konachan)
#
# Creates an isolated environment so the original end-4 script
# runs verbatim without touching your real ~/.config.

set -euo pipefail

MODULE_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TARGET="${1:-$HOME/pic/konachan}"
ORIGINAL="$MODULE_DIR/scripts/colors/random/random_konachan_wall.sh"
# Resolve TARGET to absolute path (before we override HOME)
# Handle ~, relative paths, and non-existent dirs
TARGET="$(eval echo "$TARGET")"                         # expand ~
if [[ "$TARGET" != /* ]]; then TARGET="$PWD/$TARGET"; fi  # make absolute
TARGET="$(realpath -m "$TARGET")"                         # canonicalize

# Temp HOME: shadow .config/illogical-impulse/ to suppress jq errors
TMP_HOME="$(mktemp -d)"
mkdir -p "$TMP_HOME/.config/illogical-impulse"
echo '{}' > "$TMP_HOME/.config/illogical-impulse/config.json"
export HOME="$TMP_HOME"

# Temp XDG_CONFIG_HOME: shadow user-dirs.dirs to redirect Pictures
TMP_XDG="$(mktemp -d)"
printf 'XDG_PICTURES_DIR="%s"\n' "$TARGET" > "$TMP_XDG/user-dirs.dirs"
export XDG_CONFIG_HOME="$TMP_XDG"

# Temp XDG_CACHE/STATE: prevent pollution
export XDG_CACHE_HOME="$(mktemp -d)"
export XDG_STATE_HOME="$(mktemp -d)"

# Combined cleanup
trap 'rm -rf "$TMP_HOME" "$TMP_XDG" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"' EXIT

mkdir -p "$TARGET"

# SOCKS5 proxy for curl (xray on 127.0.0.1:10808)
# Override with: SK_SOCKS=socks5h://host:port sk [dir]
SK_SOCKS="${SK_SOCKS:-socks5h://127.0.0.1:10808}"
export https_proxy="$SK_SOCKS"
export http_proxy="$SK_SOCKS"

exec "$ORIGINAL"
