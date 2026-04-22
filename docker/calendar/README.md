# Calendar stack (Radicale + sync)

This folder runs a local CalDAV server (**Radicale**) and one-or-more **sync** containers that publish calendars into Radicale as `.ics` collections.

- Radicale listens on `127.0.0.1:5232` (see `compose.yaml`).
- Each `sync-*` service writes/updates one calendar collection in Radicale via HTTP `PUT`.
- Sync config is a JSON file at `/data/calendar.json` (mounted from `~/.calendar/data/<name>/calendar.json`).

## What you get

- **Local CalDAV server**: use in desktop/mobile clients (DAVx⁵, iOS/macOS Calendar, Thunderbird, etc.).
- **Two sync modes**:
  - **ICS**: download an external `.ics` feed URL periodically and upload into Radicale.
  - **Google (OAuth)**: read Google Calendar via API (private calendars supported) → generate ICS → upload into Radicale.

## Prereqs

- Docker + Docker Compose.
- A place on your host for persistent data (this stack uses `~/.calendar/...`).

## 1) Create host folders

```bash
mkdir -p ~/.calendar/{radicale/{etc,var},data/{personal,astra,tonic},credentials,chronos}
```

## 2) Copy the example config into `~/.calendar`

This repo ships working examples under `docker/calendar/example_config/`.

### Radicale config

Copy these files:

- `docker/calendar/example_config/radicale/etc/default.conf` → `~/.calendar/radicale/etc/default.conf`
- `docker/calendar/example_config/radicale/etc/rights` → `~/.calendar/radicale/etc/rights`

Optional (only if you enable htpasswd auth; see below):

- `docker/calendar/example_config/radicale/etc/users.example` → `~/.calendar/radicale/etc/users`

### Sync config (one folder per sync container)

Copy the calendar JSON you want, per service:

- `docker/calendar/example_config/data/sync-personal/calendar.json` → `~/.calendar/data/personal/calendar.json`
- `docker/calendar/example_config/data/sync-astra/calendar.json` → `~/.calendar/data/astra/calendar.json`
- `docker/calendar/example_config/data/sync-tonic/calendar.json` → `~/.calendar/data/tonic/calendar.json`

Then edit each `~/.calendar/data/*/calendar.json` to match your calendars (details below).

### Chronos MCP (`accounts.json`)

JSON cannot “read” `.env`; values in a static file are fixed unless you generate the file (for example with `envsubst`). This stack avoids duplicating Radicale credentials in JSON:

- Compose passes **`RADICALE_USER`** / **`RADICALE_PASSWORD`** from `docker/calendar/.env` into the container as **`CALDAV_USERNAME`** / **`CALDAV_PASSWORD`** (and **`CALDAV_BASE_URL=http://radicale:5232`**). Chronos creates the **`default`** CalDAV account from those variables whenever **`default` is not already listed** in `accounts.json`.

- **`~/.calendar/chronos/accounts.json`** is mounted at `/root/.chronos/accounts.json`. Copy the example (empty `accounts`) so the default account comes only from `.env`:

  - `docker/calendar/example_config/chronos/accounts.json` → `~/.calendar/chronos/accounts.json`

To use **extra** CalDAV accounts (same or other servers), add entries under `accounts` and set `default_account` if needed; see [Chronos MCP configuration](https://github.com/democratize-technology/chronos-mcp#configuration). If you define an account with alias **`default`** in JSON, that entry wins and env-based `default` is not added.

## 3) Configure environment variables (`docker/calendar/.env`)

This compose file reads env vars from `docker/calendar/.env`.

Start from the example:

- `docker/calendar/.env.example` → `docker/calendar/.env`

Required values:

- `RADICALE_USER`: the Radicale principal / URL path the sync containers will write to.
- `RADICALE_PASSWORD`: password used for Basic Auth by the sync containers.
- `SYNC_INTERVAL_SECONDS`: how often sync runs (default: `1800`).

Notes:

- The sync containers **require** `RADICALE_USER` and `RADICALE_PASSWORD` to be set (even if Radicale auth is disabled), because the sync code always sends a Basic Auth header.
- `RADICALE_BASE_URL` is already set in `compose.yaml` for sync containers (`http://radicale:5232`).

## 4) Decide Radicale authentication mode (recommended: enable auth)

Radicale is configured by `~/.calendar/radicale/etc/default.conf`.

In the provided example (`docker/calendar/example_config/radicale/etc/default.conf`):

- `[auth] type = none` (no server-side auth)

This is simplest, but anyone who can reach the port can read/write calendars.

### Recommended: enable htpasswd auth

1) Edit `~/.calendar/radicale/etc/default.conf`:

- Change:
  - `type = none`
- To:
  - `type = htpasswd`

2) Create `~/.calendar/radicale/etc/users` as an htpasswd file.

Example using Apache htpasswd tool (pick one):

```bash
# Option A: if you have apache2-utils installed
htpasswd -c ~/.calendar/radicale/etc/users "$RADICALE_USER"

# Option B: run htpasswd in a container (no host install needed)
docker run --rm -it -v ~/.calendar/radicale/etc:/out httpd:2.4-alpine \
  htpasswd -c /out/users "$RADICALE_USER"
```

Then set `RADICALE_PASSWORD` in `docker/calendar/.env` to the password you chose.

## 5) Configure calendars to sync

Each sync container reads `/data/calendar.json` (mounted from your host).

Common fields:

- `sync_type`: `"ics"` or `"google"`
- `id`: used as the default Radicale collection name (and default URL path component)
- `name`: calendar display name (written as `X-WR-CALNAME` in the ICS)
- `href` (optional): overrides the Radicale collection path (defaults to `id`)

### A) ICS sync (external `.ics` URL → Radicale)

Edit `~/.calendar/data/personal/calendar.json` (and/or `tonic`) to:

- `sync_type`: `"ics"`
- `external_ics_url`: the URL to download, e.g. `https://example.com/calendar.ics`

Where to get an ICS URL:

- Many providers offer an “iCal/ICS subscription URL”.
- For Google Calendar specifically (non-OAuth):
  - In Google Calendar settings for a calendar, look for **“Secret address in iCal format”** (private) or **“Public address in iCal format”** (public calendars only).

Important:

- If the ICS URL is secret, treat it like a password (don’t commit it).

### B) Google sync (OAuth → Google Calendar API → Radicale)

Edit `~/.calendar/data/astra/calendar.json` to:

- `sync_type`: `"google"`
- `google_calendar_id`: usually `"primary"`, or a specific calendar ID (often looks like an email address).

This mode needs:

- An OAuth client JSON at `~/.calendar/credentials/google-oauth-client.json` (mounted read-only into the container as `/credentials/google-oauth-client.json`).
- A token file created by a one-time auth flow at `~/.calendar/data/astra/token.json` (mounted as `/data/token.json`).

## 6) Create the Google OAuth app in Google Cloud (for `sync_type: google`)

This is the exact flow the `sync` container uses: `InstalledAppFlow.run_local_server(...)` with a local callback.

### 6.1 Create/select a project

- Go to Google Cloud Console → select an existing project or create a new one.

### 6.2 Enable the Google Calendar API

- APIs & Services → Library → enable **Google Calendar API** for the project.

### 6.3 Configure the OAuth consent screen

- APIs & Services → OAuth consent screen
- Choose **External** (usually) or **Internal** (Workspace-only).
- Fill in required app info.
- Add the scope:
  - `.../auth/calendar.readonly`

If your consent screen is in **Testing** mode, add your Google account as a **Test user**.

### 6.4 Create OAuth client credentials (Desktop app)

- APIs & Services → Credentials → Create Credentials → **OAuth client ID**
- Application type: **Desktop app**
- Download the JSON.

Save it here:

- `~/.calendar/credentials/google-oauth-client.json`

## 7) Run the one-time Google auth flow (generates `token.json`)

The `sync-astra` service in `compose.yaml` is already configured for OAuth:

- `OAUTH_PORT=8090`
- `GOOGLE_CREDENTIALS_PATH=/credentials/google-oauth-client.json`
- `GOOGLE_TOKEN_PATH=/data/token.json`

Run:

```bash
cd docker/calendar
docker compose run --rm -p 8090:8090 sync-astra python sync.py auth
```

What happens:

- The container starts a temporary web server on port `8090`.
- It prints a URL; open it on your host, sign in, and grant access.
- The token is saved to `~/.calendar/data/astra/token.json`.

If you ever need to re-auth:

- Delete `~/.calendar/data/astra/token.json` and re-run the auth command above.

## 8) Start the stack

```bash
cd docker/calendar
docker compose up -d --build
```

Check logs:

```bash
docker compose logs -f radicale
docker compose logs -f sync-personal
docker compose logs -f sync-astra
```

## 9) Calendar MCP (Cursor / other MCP clients)

The **`chronos-mcp`** service runs **[Chronos MCP](https://github.com/democratize-technology/chronos-mcp)**. Radicale credentials for the default account come from **`docker/calendar/.env`** via compose (`CALDAV_*`, see §2). **`~/.calendar/chronos/accounts.json`** is optional scaffolding for extra accounts (or leave `accounts` empty).

- **Transport**: FastMCP **SSE** on container port `8000`, published on the host as **`127.0.0.1:8799`**.
- **Local MCP URL**: `http://127.0.0.1:8799/sse` (SSE path; message POSTs use `/messages/` on the same port per FastMCP defaults).

Logs:

```bash
docker compose logs -f chronos-mcp
```

## 10) Connect your calendar client (CalDAV)

Radicale endpoint (from the host):

- Base URL: `http://127.0.0.1:5232/`

Credentials:

- Username: value of `RADICALE_USER` in `docker/calendar/.env`
- Password: value of `RADICALE_PASSWORD` in `docker/calendar/.env`

Collection URLs:

- Collections are written to: `/{RADICALE_USER}/{href-or-id}`
- Example (personal): `http://127.0.0.1:5232/liempo/personal`

Tip:

- Some clients want only the base URL and will discover collections automatically.

## 11) Adding another calendar

1) Create a new host folder: `~/.calendar/data/<new>/`
2) Create `~/.calendar/data/<new>/calendar.json` (copy an example and edit).
3) Add a new service to `compose.yaml` by copying one of the existing `sync-*` services and changing:
   - container_name
   - the `~/.calendar/data/<new>:/data` volume
   - (for google mode) set `GOOGLE_TOKEN_PATH` to `/data/token.json` and mount credentials as needed
4) Restart:

```bash
cd docker/calendar
docker compose up -d --build
```

