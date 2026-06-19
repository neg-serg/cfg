#!/bin/bash
# Build the Bluefin custom image locally with podman
# WARNING: This will download ~5GB base image and install 428+ RPMs
# ETA: 20-60 minutes depending on network/disk speed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="bluefin-custom"
IMAGE_TAG="latest"

echo "=== Building bluefin-custom image ==="
echo "This will:"
echo "  1. Pull Bluefin DX base image (~5 GB)"
echo "  2. Enable RPM Fusion + COPR repos"
echo "  3. Install 428 RPM packages"
echo "  4. Install Flatpak + Brew + Cargo + Pip + Go"
echo "  5. Download binaries + build from source"
echo ""
echo "Build started at $(date)"

cd "$SCRIPT_DIR"

# Ensure the combined Containerfile is ready
if [ ! -f Containerfile.combined ]; then
    echo "ERROR: Containerfile.combined not found. Run generate-bluefin-image.py first."
    exit 1
fi

cp Containerfile.combined Containerfile

# Build
podman build \
    --squash-all \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file Containerfile \
    .

echo ""
echo "=== Build complete: ${IMAGE_NAME}:${IMAGE_TAG} ==="
echo "To publish to ghcr.io:"
echo "  podman push ${IMAGE_NAME}:${IMAGE_TAG} ghcr.io/YOUR_USER/${IMAGE_NAME}:${IMAGE_TAG}"
