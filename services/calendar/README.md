# Calendar service (Radicale + sync jobs)

This module runs a local **CalDAV** server (Radicale) plus background sync jobs that upload iCalendar data into Radicale collections:

- **`radicale`**: CalDAV server (stores calendars and serves clients)
- **`sync-astra`**: Google Calendar → iCalendar → Radicale (OAuth)
- **`sync-tonic` / `sync-personal`**: ICS URL → Radicale (no OAuth)

All services are defined in `compose.yaml`.

## Prerequisites

- Docker + Docker Compose
- A Radicale username/password (HTTP basic auth)
- For Google sync: a Google Cloud OAuth client + Calendar API enabled

## Configuration

### 1) Environment file

Copy and edit `.env`:

```bash
cp .env.example .env
```

Required keys:

- **`RADICALE_USER`** / **`RADICALE_PASSWORD`**: used by sync jobs to PUT calendars into Radicale.
- **`RADICALE_BASE_URL`**: keep default `http://radicale:5232` unless you changed container networking.
- **`SYNC_INTERVAL_SECONDS`**: how often sync runs (default 1800s).

### 2) Radicale users

The `radicale` container uses the files in `./radicale/etc` and stores data in `./radicale/var`.

Make sure Radicale’s users file matches your `.env` credentials:

- `./radicale/etc/users` (format depends on the Radicale image; keep it consistent with your existing setup)

### 3) Per-calendar sync config (what gets synced where)

Each sync job reads a JSON config from **`/data/calendar.json`** inside its container.

Because the compose file mounts `./data/<sync-name>:/data`, you should place a config at:

- **Google**: `./data/sync-astra/calendar.json`
- **ICS**: `./data/sync-tonic/calendar.json`, `./data/sync-personal/calendar.json`

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

## Google OAuth setup (for `sync-astra`)

### 1) Create OAuth client in Google Cloud

In Google Cloud Console:

- Enable **Google Calendar API**
- Create an **OAuth client ID** of type **Desktop app**

Download the client JSON and save it to:

- `./credentials/google-oauth-client.json`

There is an example template at `credentials/google-oauth-client.json.example`.

### 2) Add redirect URIs

Add these redirect URIs to the OAuth client:

- `http://127.0.0.1:8090/`
- `http://localhost:8090/`

### 3) One-time login (generate token) in Docker

Run the auth command with the callback port published:

```bash
docker compose run --rm -p 8090:8090 sync-astra python sync.py auth
```

Then open the URL printed in your terminal, complete consent, and the token will be saved to the mounted data directory:

- `./data/sync-astra/token.json`

After that, the sync loop will refresh tokens automatically (when a refresh token exists).

## Running the stack

### From `~/.dots/services` (recommended)

Your root compose file (`services/compose.yaml`) includes this module. All calendar services are in a single profile named **`calendar`**.

```bash
cd ~/.dots/services
docker compose up -d 
docker compose restart
```

## HTTPS / reverse proxy

This module is set up to be used behind an nginx reverse proxy that terminates TLS and forwards `/calendar/` → `radicale:5232`.
See the comment block at the top of `compose.yaml` (and any nginx files you already have in your dotfiles) for the intended URL shape:

- `https://<host>/calendar/`

## Troubleshooting

- **OAuth redirect URI mismatch**: ensure `http://127.0.0.1:8090/` and/or `http://localhost:8090/` are added in Google Cloud.
- **Auth can’t be reached from browser**: confirm you used `-p 8090:8090` on the `auth` run.
- **Sync says “no token file”**: run the one-time `auth` command and ensure `./data/sync-astra/token.json` exists.
