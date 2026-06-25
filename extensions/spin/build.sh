#!/usr/bin/env bash
# Build & push a self-hosted Talos system extension for containerd-shim-spin.
#
# WHY: home-rss needs Spin runtime >= 3.7.0 for postgres TLS CA support
# (WIT spin-postgres@4.1.0 connection-builder + set-ca-root). The upstream
# siderolabs/spin extension only publishes up to v0.24.0 (Spin 3.6.3); the
# Renovate bump to v0.25.1 is stuck (PR #567 ships a stale checksum). This
# rebuilds the extension from the shim release ourselves until upstream ships it.
#
# Drop this once ghcr.io/siderolabs/spin:v0.25.x is published, and point
# home-cluster talos-build back at the upstream image.
set -euo pipefail

SHIM_VERSION="${SHIM_VERSION:-v0.25.1}"
IMAGE="${IMAGE:-ghcr.io/tsuguya/spin:${SHIM_VERSION}}"
# Authoritative GitHub server-side asset digest (gh api ... .assets[].digest)
SHA256="${SHA256:-1755fbeb2dec7d026faf8c37031d8a025975f5e194b782da10188206a386d6e4}"

ARCH=x86_64
URL="https://github.com/spinframework/containerd-shim-spin/releases/download/${SHIM_VERSION}/containerd-shim-spin-v2-linux-${ARCH}.tar.gz"

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo ">> downloading $URL"
curl -fsSL "$URL" -o "$work/shim.tar.gz"

echo ">> verifying sha256"
echo "${SHA256}  $work/shim.tar.gz" | sha256sum -c -

echo ">> assembling extension rootfs"
mkdir -p "$work/rootfs/usr/local/bin" "$work/rootfs/etc/cri/conf.d"
tar xf "$work/shim.tar.gz" -C "$work/rootfs/usr/local/bin"
chmod +x "$work/rootfs/usr/local/bin/containerd-shim-spin-v2"
cp "$here/10-spin.part" "$work/rootfs/etc/cri/conf.d/10-spin.part"
cp "$here/manifest.yaml" "$work/manifest.yaml"
cp "$here/Dockerfile" "$work/Dockerfile"

echo ">> building & pushing $IMAGE"
docker buildx build --platform linux/amd64 -t "$IMAGE" --push "$work"

echo ">> done: $(crane digest "$IMAGE")"
