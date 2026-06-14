#!/bin/bash
# Check which channel packages are in the store vs need building.
# Usage: scripts/guix-check-ready.sh [PKG1 PKG2 ...] [--store]
# No args = all channel packages. --store = print paths for ready ones.
# Exit: 0=all ready, 1=some need build, 2=errors.
set +e

CHANNEL="${GUIX_CHANNEL_PATH:-/home/neg/src/cfg/guix/channel}"
LFLAG="-L $CHANNEL"
STORE=0
PKGS=()

for a in "$@"; do
    case "$a" in --store) STORE=1 ;; -*) ;; *) PKGS+=("$a") ;; esac
done

if [ ${#PKGS[@]} -eq 0 ]; then
    TMP=$(mktemp)
    echo '(use-modules (custom packages all) (guix packages))
(for-each (lambda (p) (display (package-name p)) (newline)) all-custom-packages)' > "$TMP"
    mapfile -t PKGS < <(guix repl -L "$CHANNEL" "$TMP" 2>/dev/null | grep -E '^[a-z]')
    rm -f "$TMP"
fi

READY=0; NEED=0; FAIL=0
echo "Checking ${#PKGS[@]} packages..."

for pkg in "${PKGS[@]}"; do
    [ -z "$pkg" ] && continue
    out=$(guix build $LFLAG "$pkg" --no-grafts --dry-run 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        if echo "$out" | grep -q 'will be built'; then
            echo "🔧 $pkg"
            ((NEED++))
        else
            [ $STORE -eq 1 ] && echo "✅ $pkg"
            ((READY++))
        fi
    else
        echo "❌ $pkg"
        ((FAIL++))
    fi
done

printf "\n✅ %d  🔧 %d  ❌ %d\n" $READY $NEED $FAIL
[ $NEED -eq 0 ] && [ $FAIL -eq 0 ] && exit 0
[ $FAIL -gt 0 ] && exit 2
exit 1
