[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/nezha-1?utm_medium=integration&utm_source=button&utm_campaign=nezha)

# Nezha on Railway

One-click Railway template for [Nezha](https://github.com/nezhahq/nezha), a lightweight self-hosted server and website monitoring dashboard. Small agents on your machines report CPU, memory, disk, traffic and uptime to the dashboard over gRPC.

This repo is what the template builds: a `Dockerfile` that pins the official image and a small start script.

## What it deploys

| Service | What it does |
|---|---|
| `Nezha` | The dashboard (web UI, API and agent gRPC endpoint on one port), built from this repo. Data on a volume at `/dashboard/data`. |

- Nezha dashboard **v2.7.0**, `ghcr.io/nezhahq/nezha:v2.7.0@sha256:7b25a608979daf84ea69afc45d56f3c9fd79cc6819d7cd606114bc6f9a2d3de7`.
- Public HTTPS domain for the web UI, health check on `/api/v1/setting`.
- A Railway TCP proxy on the same port for the agents (gRPC can't pass through Railway's HTTP domain).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | Admin login name, set on first boot. |
| `ADMIN_PASSWORD` | generated (`${{secret(24)}}`) | Admin password, set on first boot. Read it in the service's Variables tab. |
| `PORT` | `8008` | Port the dashboard listens on; Railway routes the domain and the TCP proxy here. |

The dashboard ships with an `admin/admin` login on a fresh database. The start script replaces it with `ADMIN_USERNAME`/`ADMIN_PASSWORD` before the dashboard opens to the internet, so nobody can claim the admin account first. After the first boot, change the password in the dashboard (Profile); changing the variable later has no effect.

## After deploying

1. Open the service's public domain and sign in with `ADMIN_USERNAME` and `ADMIN_PASSWORD`.
2. In **Settings**, check that "Dashboard server domain/IP for agent connections" shows the TCP proxy address (`something.proxy.rlwy.net:PORT`) and that TLS is off.
3. In **Servers**, click the install-command button and run that command on each machine you want to monitor.

Agent traffic through the TCP proxy is not encrypted (the agent's secret travels in plain text). For monitoring over the internet, consider putting your own TLS proxy in front, or keep agents on networks you trust.

## Updates

Pushes to `main` of this repo bump the pinned Nezha version. Railway shows deployers of the template an "update available" notice; apply it from your project when you're ready. Read [`CHANGELOG.md`](CHANGELOG.md) first. Your data stays on the volume.

## Resources

Nezha is light: about 30–60 MB of RAM for a handful of agents, so Railway's smallest instance (0.5 GB) is enough. The image sets `GOMEMLIMIT=360MiB`.

## Licence

Nezha is licensed under the WTFPL. This wrapper is provided as is.
