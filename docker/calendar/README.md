# Calendar service (Radicale + sync jobs)

This module runs a local **CalDAV** server (Radicale) plus background sync jobs that upload iCalendar data into Radicale collections:

- **`radicale`**: CalDAV server (stores calendars and serves clients)
- **`sync-astra`**: sync job (Google or ICS depending on `sync_type`)
- **`sync-tonic` / `sync-personal`**: sync jobs (Google or ICS depending on `sync_type`)

All services are defined in `compose.yaml`.

## Prerequisites

- Docker + Docker Compose
- A Radicale username/password (HTTP basic auth)
- For Google sync: a Google Cloud OAuth client + Calendar API enabled

## Configuration

### 1) Environment file

Create **`docker/calendar/.env`** in this directory (gitignored at repo root). Docker Compose loads it automatically for variable substitution.

Template:

- `docker/calendar/.env.example` → copy to `docker/calendar/.env` and fill in real values.

Required keys:

- **`RADICALE_USER`** / **`RADICALE_PASSWORD`**: used by sync jobs to PUT calendars into Radicale.
- **`RADICALE_BASE_URL`**: keep default `http://radicale:5232` unless you changed container networking.
- **`SYNC_INTERVAL_SECONDS`**: how often sync runs (default 1800s).

### 2) Radicale users

The `radicale` container uses the files in `~/.calendar/radicale/etc` and stores data in `~/.calendar/radicale/var`.

Make sure Radicale’s users file matches your `.env` credentials:

- `~/.calendar/radicale/etc/users` (format depends on the Radicale image; see `users.example` if present)

Templates you can copy from this repo:

- `docker/calendar/example_config/radicale/etc/default.conf` → `~/.calendar/radicale/etc/default.conf`
- `docker/calendar/example_config/radicale/etc/rights` → `~/.calendar/radicale/etc/rights`
- `docker/calendar/example_config/radicale/etc/users.example` → reference for creating `~/.calendar/radicale/etc/users`

### 3) Per-calendar sync config (what gets synced where)

Each sync job reads a JSON config from **`/data/calendar.json`** inside its container.

Because the compose file mounts `~/.calendar/data/<sync-name>:/data`, place a config at:

- **`sync-astra`**: `~/.calendar/data/sync-astra/calendar.json`
- **`sync-tonic`**: `~/.calendar/data/sync-tonic/calendar.json`
- **`sync-personal`**: `~/.calendar/data/sync-personal/calendar.json`

Templates you can copy from this repo:

- `docker/calendar/example_config/data/sync-astra/calendar.json`
- `docker/calendar/example_config/data/sync-tonic/calendar.json`
- `docker/calendar/example_config/data/sync-personal/calendar.json`

Example seed commands (copies templates into `~/.calendar`):

```bash
mkdir -p ~/.calendar/data/sync-astra ~/.calendar/data/sync-tonic ~/.calendar/data/sync-personal
cp -n ~/.dots/docker/calendar/example_config/data/sync-astra/calendar.json ~/.calendar/data/sync-astra/calendar.json
cp -n ~/.dots/docker/calendar/example_config/data/sync-tonic/calendar.json ~/.calendar/data/sync-tonic/calendar.json
cp -n ~/.dots/docker/calendar/example_config/data/sync-personal/calendar.json ~/.calendar/data/sync-personal/calendar.json
```

Common fields (all sync types):

- **`id`**: a stable identifier used as the default Radicale collection href
- **`href`** (optional): override the Radicale collection path (defaults to `id`)
- **`name`** (optional): calendar display name (Google sync sets `X-WR-CALNAME`)

Google sync (`sync_type: "google"`) additionally requires:

- **`sync_type`: `"google"`**
- **`google_calendar_id`** (optional): defaults to `"primary"`

ICS sync (`sync_type: "ics"`) additionally requires:

- **`sync_type`: `"ics"`**
- **`external_ics_url`**: the URL to download the `.ics` feed from

## Google OAuth setup 

### 1) Create OAuth client in Google Cloud

In Google Cloud Console:

- Enable **Google Calendar API**
- Create an **OAuth client ID** of type **Desktop app**

Download the client JSON and save it to:

- `~/.calendar/credentials/google-oauth-client.json`

There is an example template at `docker/calendar/credentials/google-oauth-client.json.example`.

### 2) Add redirect URIs

Add these redirect URIs to the OAuth client:

- `http://127.0.0.1:8090/`
- `http://localhost:8090/`

### 3) One-time login (generate token) in Docker

Run the auth command with the callback port published:

```bash
cd ~/.dots/docker/calendar
docker compose run --rm -p 8090:8090 sync-astra python sync.py auth
```

Then open the URL printed in your terminal, complete consent, and the token will be saved to the mounted data directory:

- `~/.calendar/data/sync-astra/token.json`

After that, the sync loop will refresh tokens automatically (when a refresh token exists).

## Running the stack

### On homestation (systemd)

**`calendar.service`** runs Compose from **`~/.dots/docker/calendar`** (see `system/services.nix`).

- Logs: `journalctl -u calendar -f`
- Restart: `sudo systemctl restart calendar`

### Manually

```bash
cd ~/.dots/docker/calendar
docker compose up
```

Use **`docker compose up -d`** if you want detached containers without systemd.

## HTTPS / Tailscale Serve

Compose binds Radicale to **`127.0.0.1:5232`** only. This repo **does not** run **`tailscale serve`** from systemd; expose CalDAV to your tailnet yourself (e.g. [Tailscale Serve](https://tailscale.com/docs/reference/tailscale-cli/serve)) after Radicale is up.

Example (run on the host as root; define **`svc:calendar`** and **`tcp:8443`** in the [admin Services](https://login.tailscale.com/admin/services) UI if you use [Tailscale Services](https://tailscale.com/docs/features/tailscale-services)):

```bash
sudo tailscale serve --service=svc:calendar --bg --https=8443 http://127.0.0.1:5232
```

Configure CalDAV clients with that HTTPS origin (no `/calendar/` path prefix when using Serve on a dedicated port).

**Web UI:** if you use Serve on **8443**, open **`https://<tailscale-host-or-service>:8443/`** (Radicale redirects to **`/.web/`**). Log in with **`RADICALE_USER`** / **`RADICALE_PASSWORD`** from `.env` (same as **`~/.calendar/radicale/etc/users`**). Locally: **`http://127.0.0.1:5232/`**.

**NixOS firewall:** allow the TCP ports you pass to **`tailscale serve`** (e.g. **8443**), or Serve cannot accept connections.

## Troubleshooting

- **Web portal blank or “Radicale works!” only:** ensure **`~/.calendar/radicale/etc/default.conf`** has **`[web] type = internal`** and **`[auth] type = htpasswd`** (not **`none`**) when using **`~/.calendar/radicale/etc/users`**. Templates live in `docker/calendar/radicale/etc/`. Restart: **`sudo systemctl restart calendar`**.
- **OAuth redirect URI mismatch**: ensure `http://127.0.0.1:8090/` and/or `http://localhost:8090/` are added in Google Cloud.
- **Auth can’t be reached from browser**: confirm you used `-p 8090:8090` on the `auth` run.
- **Sync says “no token file”**: run the one-time `auth` command and ensure `~/.calendar/data/sync-astra/token.json` exists.
