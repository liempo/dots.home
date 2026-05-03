# Calendar stack

**Radicale** (CalDAV) on **`127.0.0.1:5232`**, **[Radicalize](https://github.com/liempo/radicalize)** to pull Google / ICS / CalDAV into Radicale, and **Chronos MCP** on **`mcp-net`** (container port **8000**). Radicalize source lives in **`docker/calendar/radicalize`** as a **git submodule** (see repo **`.gitmodules`**; remote **`git@github.com.personal:liempo/radicalize.git`**).

systemd: **`calendar`** · compose: [`compose.yaml`](compose.yaml)

---

## Host paths (`~/.calendar/`)

| Host | In container | Purpose |
| ---- | -------------- | ------- |
| **`~/.calendar/radicale/etc`**, **`~/.calendar/radicale/var`** | `/radicale/etc`, `/radicale/var` | Radicale config + database (same tree as **`radicale/.env`**) |
| **`~/.calendar/radicale/.env`** | `env_file` (Chronos); overlay **`/data/calendar/.env`** (Radicalize, **not** `:ro`) | **`radicale_env`** from **`secrets/calendar.yaml`** (SOPS → Home Manager); read-write so the Radicalize entrypoint **`chown -R`** on the data dir does not fail on **`.env`** |
| **`~/.calendar/chronos/accounts.json`** | `/root/.chronos/accounts.json` | Chronos MCP (**`chronos_accounts_json`**) |
| **`~/.calendar/google/oauth.json`** | **`/data/calendar/credentials/google-oauth-client.json`** | Google Desktop OAuth client JSON (**`google_oauth_client_json`**); bind-mounted under Radicalize’s default credentials name (**writable** bind, like **`.env`**, for **`chown`**) |
| **`~/.calendar/radicalize`** | `/data/calendar` | Radicalize data: **`sources/`**, **`tokens/`**, optional **`vdirsyncer/`** (OAuth client file is the mount above, not stored inside this tree) |

If **`~/.calendar/radicalize`** was first created by Docker as **root**, fix ownership once:

```bash
sudo chown -R "$USER":users ~/.calendar/radicalize
```

Radicalize populates **`~/.calendar/radicalize`** (e.g. **`radicalize add`** / **`init`**); see [upstream](https://github.com/liempo/radicalize).

---

## SOPS / Home Manager

Edit **`secrets/calendar.yaml`** (`sops secrets/calendar.yaml`) — keys **`radicale_env`**, **`chronos_accounts_json`**, **`google_oauth_client_json`**. See [`.skills/sops-secrets/SKILL.md`](../../.skills/sops-secrets/SKILL.md).

After **`nixos-rebuild switch --flake ~/.dots#homestation`**, confirm **`~/.calendar/radicale/.env`**, **`~/.calendar/radicale/etc`** / **`var`** (Radicale), **`~/.calendar/google/oauth.json`**, **`~/.calendar/chronos/accounts.json`**, and (after first Radicalize use) **`~/.calendar/radicalize/`** layout exist before starting **`calendar.service`**.

If the OAuth client JSON only exists under an older path (e.g. **`~/.calendar/credentials/google-oauth-client.json`**), copy it into place: **`mkdir -p ~/.calendar/google && cp … ~/.calendar/google/oauth.json`**, or add **`google_oauth_client_json`** to **`secrets/calendar.yaml`** and rebuild.

### Migrating from older layouts

Adjust sources if your paths differ; then:

```bash
mkdir -p ~/.calendar/radicale ~/.calendar/google ~/.calendar/chronos ~/.calendar/radicalize
# Radicale env (was ~/.dots/docker/calendar/.env)
cp -a ~/.dots/docker/calendar/.env ~/.calendar/radicale/.env
# OAuth client (was under radicalized/ or credentials/)
cp -a ~/.calendar/radicalized/credentials/google-oauth-client.json ~/.calendar/google/oauth.json 2>/dev/null \
  || cp -a ~/.calendar/credentials/google-oauth-client.json ~/.calendar/google/oauth.json 2>/dev/null \
  || true
# Radicalize state directory name
[ -d ~/.calendar/radicalized ] && [ ! -d ~/.calendar/radicalize ] && mv ~/.calendar/radicalized ~/.calendar/radicalize
# Legacy Radicale host dirs (only if data still lives under ~/.radicale/ from old compose)
# rsync -a ~/.radicale/etc/ ~/.calendar/radicale/etc/; rsync -a ~/.radicale/var/ ~/.calendar/radicale/var/
# Chronos (unchanged path; skip if already correct)
# cp -a ~/.calendar/chronos/accounts.json ~/.calendar/chronos/accounts.json
```

---

## Radicalize

After Home Manager applies this flake’s **`home/liempo.nix`**, the **`radicalize`** command runs **`docker compose run`** in **`~/.dots/docker/calendar/`** with **`RADICALIZED_UID`** / **`RADICALIZED_GID`**, **`127.0.0.1:8090:8090`** published for OAuth, and **`--data-dir /data/calendar`** appended (same as the stack). Example: **`radicalize sync`**, **`radicalize list`**.

- **CalDAV sources** need **`vdirsyncer`** on the image **`PATH`** if you use **`sync_type: caldav`**.
- **Google OAuth client JSON** on the host is **`~/.calendar/google/oauth.json`** (SOPS → HM). Inside the container it appears as **`/data/calendar/credentials/google-oauth-client.json`** (Radicalize default).
- **Google OAuth from Docker** (browser flow): publish **8090**; set **`RADICALIZED_UID`** / **`RADICALIZED_GID`** (same as in [Radicalize container user](#radicalize-container-user)); replace **`SOURCE_ID`** with the **`id`** from **`~/.calendar/radicalize/sources/`**:  
  **`docker compose run --rm -p 8090:8090 radicalize auth SOURCE_ID --data-dir /data/calendar`**  
  Use the same **`-p 8090:8090`** when running **`radicalize add`** if you answer **yes** to “Run Google OAuth now?”.

---

## One-time Radicale prep

**Radicalize** creates its own data layout with **`radicalize init`** (Home Manager wrapper) or **`docker compose run --rm radicalize init --data-dir /data/calendar`**. **Radicale** still needs config and storage dirs on the host before the stack starts:

```bash
mkdir -p ~/.calendar/radicale/etc ~/.calendar/radicale/var
# Optional: copy or adapt from this repo’s samples under docker/calendar/radicale/etc/ (default.conf, rights, users.example).
```

---


## Radicalize container user

The image starts as **root**, **`docker-entrypoint.sh`** **`chown`**s **`RADICALIZE_DATA`** to **`RADICALIZED_UID:GID`**, then runs **`radicalize`** via **`gosu`** as that user (see [upstream](https://github.com/liempo/radicalize)). **`calendar.service`** sets **`RADICALIZED_UID`** / **`RADICALIZED_GID`** from NixOS **`liempo`** (see [`system/services.nix`](../system/services.nix)).

If you run Compose **by hand** (not systemd), export the same ids first:

```bash
export RADICALIZED_UID=$(id -u) RADICALIZED_GID=$(id -g)
docker compose up -d
```

---

## Operations

| Task | Command / note |
| ---- | -------------- |
| Rebuild Radicalize image | From **`docker/calendar/`**: **`docker compose build radicalize`** (context is **`./radicalize`** submodule; update with **`git -C radicalize pull`** then rebuild) |
| Stack logs | **`journalctl -u calendar -f`** or **`docker compose logs -f`** in **`docker/calendar/`** |
