# Changelog

Each entry is one version of this template. Breaking changes are listed first.
Deployers get an "update available" notice in Railway when a new entry lands on `main`.

## 2.7.0-1 (2026-11-23)

- First release: Nezha dashboard `v2.7.0` (`ghcr.io/nezhahq/nezha:v2.7.0@sha256:7b25a608979daf84ea69afc45d56f3c9fd79cc6819d7cd606114bc6f9a2d3de7`).
- The default `admin/admin` login is replaced on first boot with the generated `ADMIN_PASSWORD`.
- SQLite database, config and secrets on a volume at `/dashboard/data`.
- Agents connect over gRPC through a Railway TCP proxy; the agent install command shows that address.
- README: Deploy on Railway button for the published template `nezha-1`.
