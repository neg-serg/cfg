#!/usr/bin/env zsh
# Install all user packages on CachyOS after bootstrap
# Run as root after first boot (or from arch-chroot)
#
# Usage:
#   sudo ./scripts/cachyos-packages.sh
#
# Requires: paru (installed by bootstrap)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "error: must run as root" >&2
	exit 1
fi

SCRIPT_DIR="${0:A:h}"
SALT_DIR="${SALT_DIR:-$(dirname "$SCRIPT_DIR")}"
YAML_FILE="${SALT_DIR}/states/data/packages.yaml"
# Fallback: when run from /root inside chroot, packages.yaml is copied alongside
[[ -f "$YAML_FILE" ]] || YAML_FILE="/root/packages.yaml"

if [[ ! -f "$YAML_FILE" ]]; then
	echo "error: packages.yaml not found at ${YAML_FILE}" >&2
	exit 1
fi

# Retry wrapper for transient network failures (AUR RPC resets, mirror hiccups)
# Usage: retry <max_attempts> <description> <command...>
retry() {
	local max_attempts="$1" desc="$2"
	shift 2
	local attempt=1 delay=10
	while true; do
		echo "==> [$desc] attempt $attempt/$max_attempts"
		if "$@"; then
			return 0
		fi
		if ((attempt >= max_attempts)); then
			echo "==> [$desc] FAILED after $max_attempts attempts" >&2
			return 1
		fi
		echo "==> [$desc] failed, retrying in ${delay}s..."
		sleep "$delay"
		((attempt++))
		((delay *= 2))
	done
}

# ===================================================================
# OFFICIAL PACKAGES (pacman)
# ===================================================================
# Extracted from states/data/packages.yaml — all categories except "aur",
# excluding packages built from local PKGBUILDs.

mapfile -t PACMAN_PKGS < <(python3 - "$YAML_FILE" <<'PYEOF'
import sys, yaml
custom_pkgs = {"raise", "neg-pretty-printer", "richcolors", "albumdetails", "taoup", "iosevka-neg-fonts"}
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
pkgs = set()
for category, items in data.items():
    if category == "aur" or not items:
        continue
    pkgs.update(pkg for pkg in items if pkg not in custom_pkgs)
for pkg in sorted(pkgs):
    print(pkg)
PYEOF
)

# ===================================================================
# AUR PACKAGES (paru)
# ===================================================================
# Extracted from states/data/packages.yaml — "aur" category only,
# excluding packages built from local PKGBUILDs.

mapfile -t AUR_PKGS < <(python3 - "$YAML_FILE" <<'PYEOF'
import sys, yaml
custom_pkgs = {"raise", "neg-pretty-printer", "richcolors", "albumdetails", "taoup", "iosevka-neg-fonts"}
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
items = data.get("aur", []) or []
pkgs = [pkg for pkg in items if pkg not in custom_pkgs]
for pkg in sorted(pkgs):
    print(pkg)
PYEOF
)

# ===================================================================
# CUSTOM PKGBUILD PACKAGES (makepkg)
# ===================================================================
# Packages with no official/AUR equivalent, built from local PKGBUILDs.

PKGBUILD_DIR="${SALT_DIR}/build/pkgbuilds"

# iosevka-neg-fonts last: 2+ hour build
CUSTOM_PKGS=(raise neg-pretty-printer richcolors albumdetails taoup iosevka-neg-fonts)

pkgbuild_install() {
	# Provide iosevka design config alongside its PKGBUILD
	cp "${SALT_DIR}/build/iosevka-neg.toml" "${PKGBUILD_DIR}/iosevka-neg-fonts/"

	# iosevka-neg-fonts needs ttfautohint (AUR-only, makepkg can't install it)
	if ! pacman -Q ttfautohint &>/dev/null; then
		echo "  Installing ttfautohint from AUR (needed for iosevka build)..."
		su - neg -c "paru -S --needed --noconfirm --skipreview ttfautohint"
	fi

	for pkg in "${CUSTOM_PKGS[@]}"; do
		if pacman -Q "$pkg" &>/dev/null; then
			echo "  $pkg already installed, skipping"
			continue
		fi
		if [[ ! -f "${PKGBUILD_DIR}/${pkg}/PKGBUILD" ]]; then
			echo "  WARNING: no PKGBUILD for ${pkg}, skipping" >&2
			continue
		fi
		echo "  Building ${pkg}..."
		sudo -u neg bash -c "cd '${PKGBUILD_DIR}/${pkg}' && makepkg -sfC --noconfirm"
		pacman -U --noconfirm "${PKGBUILD_DIR}/${pkg}/"*.pkg.tar.zst
	done

	# Ruby gem for taoup color output
	gem install ansi --no-document --no-user-install 2>/dev/null || true
}

# ===================================================================
# Install
# ===================================================================

pacman_install() {
	# Refresh databases — mirrors may have synced since last failure
	pacman -Sy --noconfirm
	# Delete partial/corrupted cached downloads that would block re-download
	find /var/cache/pacman/pkg/ -name '*.part' -delete 2>/dev/null || true
	# --needed skips already-installed packages (safe after partial installs)
	pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
}

paru_install() {
	# -Sy refreshes databases; --needed skips already-installed packages
	su - neg -c "paru -Sy --needed --noconfirm --noprovides --skipreview ${AUR_PKGS[*]}"
}

echo "==> Installing official packages (pacman)..."
retry 3 "pacman" pacman_install

echo ""
echo "==> Installing AUR packages (paru as user neg)..."
retry 5 "paru/AUR" paru_install || echo "WARNING: some AUR packages failed (non-fatal, continuing)"

echo ""
echo "==> Building and installing custom packages (makepkg as user neg)..."
echo "    NOTE: iosevka-neg-fonts takes 2+ hours to build"
pkgbuild_install

echo ""
echo "==> Done. All packages installed."
