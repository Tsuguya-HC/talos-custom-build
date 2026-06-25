# spin system extension (self-built)

Temporary self-hosted Talos system extension for `containerd-shim-spin`.

## Why

home-rss (Spin/WASM RSS reader) needs the Spin runtime's postgres TLS CA
support — `pg41::ConnectionBuilder` + `set_ca_root` (WIT `spin-postgres@4.1.0`),
added in Spin runtime 3.7.0. That landed in `containerd-shim-spin` **v0.25.0+**,
which bundles Spin **4.0.1**.

Upstream `ghcr.io/siderolabs/spin` only publishes up to **v0.24.0** (Spin 3.6.3,
no `set_ca_root`). The Renovate bump to v0.25.1 (siderolabs/extensions PR #567)
is stuck because it ships the **stale v0.24.0 checksum** for the v0.25.1 tarball,
so the upstream build fails. spin is an `extra`-tier extension (best-effort, no
SLA), so there's no ETA.

This rebuilds the extension ourselves from the shim release until upstream ships it.

## Format

A Talos system extension is just an OCI image with `manifest.yaml` at the root
and a `rootfs/` tree overlaid onto the host. This one carries:

- `rootfs/usr/local/bin/containerd-shim-spin-v2` — the shim binary (from the release tarball)
- `rootfs/etc/cri/conf.d/10-spin.part` — containerd runtime handler registration
- `manifest.yaml` — extension metadata

Layout verified identical to `ghcr.io/siderolabs/spin:v0.24.0` (minus the
optional SPDX SBOM, which Talos does not require).

## Build

```bash
./build.sh                 # builds & pushes ghcr.io/tsuguya/spin:v0.25.1
SHIM_VERSION=v0.25.2 SHA256=<digest> ./build.sh   # bump
```

Get `SHA256` from the authoritative GitHub asset digest:

```bash
gh api repos/spinframework/containerd-shim-spin/releases/tags/v0.25.1 \
  -q '.assets[] | select(.name=="containerd-shim-spin-v2-linux-x86_64.tar.gz").digest'
```

The pushed GHCR package must be **public** so the in-cluster imager can pull it
(set via the package settings UI; the REST API cannot change container visibility).

## Consumed by

home-cluster `manifests/talos-build/workflowtemplate.yaml` — passed to the imager
as `--system-extension-image` (digest-pinned).

## Teardown

When `ghcr.io/siderolabs/spin:v0.25.x` is published:

1. Point home-cluster `talos-build` back at the upstream image.
2. Delete this directory and the `ghcr.io/tsuguya/spin` package.
