# Tailscale

This repo enables Tailscale on the host (`system/networking.nix`) and keeps application backends bound to `127.0.0.1` (Docker Compose). If you want HTTPS access on your tailnet, use **Tailscale Serve** and (optionally) **Tailscale Services** (`svc:...`).

## Concepts

- **Serve**: publishes a local HTTP(S) handler on a Tailscale device.
- **Services** (`svc:...`): gives a stable MagicDNS name and virtual identity (TailVIP) so you can point users at `https://<service>.<tailnet>.ts.net/` rather than a specific machine.
- **Local state**: Serve/Services mappings are stored in `tailscaled` state on the host. They are **not** applied by `nixos-rebuild` in this repo.

## Prereqs

- Tailscale is enabled on the host: see `system/networking.nix`.
- Backends are running locally:
  - `calendar.service` → `http://127.0.0.1:5232`
  - `stremio.service` → `http://127.0.0.1:11470`
  - `hermes.service`:
    - dashboard → `http://127.0.0.1:9119`
    - gateway → `http://127.0.0.1:8642`
    - Honcho API (in Hermes stack) → `http://127.0.0.1:8000`

## Recommended `svc:` names (one backend per service identity)

If you want everything to use **`--https=443`**, use **different** `svc:` names for different backends. One `svc:` identity cannot map `tcp:443` to two different URLs at once.

- **`svc:calendar`** → Radicale
- **`svc:stremio`** → Stremio streaming server
- **`svc:delamain`** → Hermes dashboard
- **`svc:hermes`** → Hermes gateway
- **`svc:honcho`** → Honcho API

Create these in the admin console: `https://login.tailscale.com/admin/services`.

## Setup (commands)

Start the systemd unit, then configure Serve on the same host.

### Calendar (Radicale)

```bash
sudo systemctl start calendar
sudo tailscale serve --service=svc:calendar --bg --https=443 http://127.0.0.1:5232
```

### Stremio

```bash
sudo systemctl start stremio
sudo tailscale serve --service=svc:stremio --bg --https=443 http://127.0.0.1:11470
```

### Hermes dashboard (`delamain`)

```bash
sudo systemctl start hermes
sudo tailscale serve --service=svc:delamain --bg --https=443 http://127.0.0.1:9119
```

### Hermes gateway (`hermes`)

```bash
sudo tailscale serve --service=svc:hermes --bg --https=443 http://127.0.0.1:8642
```

### Honcho API (`honcho`)

```bash
sudo tailscale serve --service=svc:honcho --bg --https=443 http://127.0.0.1:8000
```

## Verify

```bash
sudo tailscale serve status
sudo tailscale serve get-config --all
```

## Clear / reset

Clear a single service’s handlers:

```bash
sudo tailscale serve clear svc:stremio
```

Reset all Serve config on this node:

```bash
sudo tailscale serve reset
```

## Troubleshooting

### “The service X has no Service hosts set up” (admin console)

This usually means the service host advertisement hasn’t been accepted/activated yet. Common causes:

- **Pending approval** for that Service host advertisement (approve in the Service detail page).
- **Eligibility / policy constraints** (for example, your tailnet requires service hosts to use certain tags or auto-approver rules).
- **Propagation delay / transient control-plane hiccup**: re-running the `tailscale serve --service=...` command can re-advertise.

Useful commands:

```bash
sudo tailscale status
sudo tailscale serve status --json
```

### Stremio shows a redirect to `app.strem.io`

Stremio’s `/` often returns `307` redirect to `app.strem.io` with a `streamingServer=http://127.0.0.1:11470` query param. That’s fine locally, but for remote use you generally want to use the **tailnet HTTPS** service hostname for `svc:stremio` (not `127.0.0.1` on the client machine).

