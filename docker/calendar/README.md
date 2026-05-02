# Calendar stack

Radicale + sync workers + Chronos MCP (`compose.yaml`). Operated on homestation as systemd unit **`calendar`**.

---

## Host mount points

Paths are under **`liempo`**’s home unless noted.

| Host path | Container path | Service |
| --------- | -------------- | ------- |
| **`~/.calendar/radicale/etc`** | `/radicale/etc` | `radicale` |
| **`~/.calendar/radicale/var`** | `/radicale/var` | `radicale` |
| **`~/.calendar/chronos/accounts.json`** | `/root/.chronos/accounts.json` | `chronos-mcp` |
| **`~/.calendar/data/personal`** | `/data` | `sync-personal` |
| **`~/.calendar/data/astra`** | `/data` | `sync-astra` |
| **`~/.calendar/credentials`** (read-only) | `/credentials` | `sync-astra` |
| **`~/.calendar/data/tonic`** | `/data` | `sync-tonic` |

---

## Initial setup

From `docker/calendar/` (or use absolute paths from `~/.dots`):

```bash
mkdir -p ~/.calendar/radicale/{etc,var} ~/.calendar/credentials ~/.calendar/data/{personal,astra,tonic}

cp -r example_config/radicale/etc/* ~/.calendar/radicale/etc/

install -D example_config/chronos/accounts.json ~/.calendar/chronos/accounts.json

install -D example_config/data/sync-personal/calendar.json ~/.calendar/data/personal/calendar.json
install -D example_config/data/sync-astra/calendar.json ~/.calendar/data/astra/calendar.json
install -D example_config/data/sync-tonic/calendar.json ~/.calendar/data/tonic/calendar.json
```

Edit the copied JSON under `~/.calendar/data/` for ICS URLs, Google Calendar, or other sync settings. For Google sync, see [Google Calendar OAuth](#google-calendar-oauth-sync-astra) below.

---

## Google Calendar OAuth (sync-astra)

The Google → Radicale worker is the Compose service **`sync-astra`**. It reads **`~/.calendar/data/astra/calendar.json`**, which must have `"sync_type": "google"` (see `example_config/data/sync-astra/calendar.json`).

1. **Desktop OAuth client**  
   In [Google Cloud Console](https://console.cloud.google.com/), create an OAuth client of type **Desktop app** and download the JSON. Install it as:

   **`~/.calendar/credentials/google-oauth-client.json`**

   (`sync-astra` mounts `~/.calendar/credentials` read-only at `/credentials`; `compose.yaml` sets `GOOGLE_CREDENTIALS_PATH` to that file.)

2. **One-time token**  
   From **`docker/calendar/`**, with **`docker/calendar/.env`** present (Compose substitutes `RADICALE_*` / interval for the service), run:

   ```bash
   docker compose run --rm -p 8090:8090 sync-astra python sync.py auth
   ```

   The container listens on **`0.0.0.0:8090`** (`OAUTH_PORT`); the host publishes **`127.0.0.1:8090`**. With `open_browser` disabled in the script, open the **authorization URL** printed in the terminal, sign in, and complete the redirect to `http://127.0.0.1:8090/...` on the same machine (or use an SSH port forward so that URL reaches your laptop).

   On success, the refresh token is written to **`~/.calendar/data/astra/token.json`** (`GOOGLE_TOKEN_PATH` in compose).

3. **Start the stack**  
   After `token.json` exists, start or restart the stack as usual; **`sync-astra`** will refresh the token when needed.

If the token is invalid and refresh fails, delete `~/.calendar/data/astra/token.json` and run the `docker compose run ... auth` command again.

---

## Environment file

```bash
cp .env.example .env
```

Edit **`docker/calendar/.env`**:

| Variable | Purpose |
| -------- | ------- |
| `RADICALE_USER` | Radicale principal / URL path used by sync containers |
| `RADICALE_PASSWORD` | Basic Auth password (sync always sends credentials) |
| `SYNC_INTERVAL_SECONDS` | Sync period in seconds (default `1800`) |

Optional: `RADICALE_BASE_URL` defaults to `http://radicale:5232` via compose.

Compose passes these into **`chronos-mcp`** as CalDAV defaults when **`accounts.json`** does not define a conflicting `default` account.
