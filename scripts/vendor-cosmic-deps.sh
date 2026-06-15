#!/usr/bin/env bash
# Vendor COSMIC Rust package dependencies for Guix offline builds.
# Usage: ./scripts/vendor-cosmic-deps.sh cosmic-comp epoch-1.0.16
#        ./scripts/vendor-cosmic-deps.sh cosmic-greeter epoch-1.0.16
#
# This clones the repo, runs "cargo vendor" to fetch ALL dependencies
# (including git deps), creates a .cargo/config.toml for vendored builds,
# and produces a tarball + sha256 hash for use in Guix package definitions.

set -euo pipefail

NAME="${1:-}"
TAG="${2:-}"

if [[ -z "$NAME" || -z "$TAG" ]]; then
    echo "Usage: $0 <repo-name> <git-tag>"
    echo "  e.g. $0 cosmic-comp epoch-1.0.16"
    exit 1
fi

WORKDIR="$(mktemp -d)"
OUTDIR="${PWD}/guix/channel/custom/packages"
mkdir -p "$OUTDIR"

TARBALL="${OUTDIR}/${NAME}-${TAG}-vendored.tar.zst"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "=== Cloning ${NAME} @ ${TAG} ==="
git clone --depth 1 --branch "$TAG" "https://github.com/pop-os/${NAME}.git" "$WORKDIR/$NAME"

pushd "$WORKDIR/$NAME" >/dev/null

echo "=== Vendoring dependencies (this may take a while) ==="
cargo vendor vendor >/dev/null

echo "=== Creating .cargo/config.toml ==="
mkdir -p .cargo
cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF

# Remove .git to shrink tarball
rm -rf .git

popd >/dev/null

echo "=== Creating tarball ==="
tar --zstd -cf "$TARBALL" -C "$WORKDIR" "$NAME"

SHA256=$(sha256sum "$TARBALL" | cut -d' ' -f1)
NIX_HASH=$(nix-hash --type sha256 --to-sri "${SHA256}" 2>/dev/null || echo "nix-hash not available")

echo ""
echo "=== Done ==="
echo "Tarball: ${TARBALL}"
echo "SHA256:  ${SHA256}"
if [[ -n "$NIX_HASH" ]]; then
    echo "SRI:     ${NIX_HASH}"
fi
echo ""
echo "Add to your .scm file:"
echo "  (source (origin"
echo "            (method url-fetch)"
echo "            (uri (local-file \"${TARBALL}\"))"
echo "            (sha256 (base64 \"${NIX_HASH:-FIXME}\"))))"
echo ""
echo "Or use local-file directly:"
echo "  (source (local-file \"${TARBALL}\""
echo "            #:sha256 (base64 \"${NIX_HASH:-FIXME}\")))"
