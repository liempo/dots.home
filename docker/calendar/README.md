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

Edit the copied JSON under `~/.calendar/data/` for ICS URLs, Google OAuth, or other sync settings. For Google sync, place OAuth client JSON at `~/.calendar/credentials/google-oauth-client.json` and run the one-time auth flow described in Chronos / sync tooling when needed.

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
