# Hermes stack

Hermes **gateway** and **dashboard** only (`compose.yaml`). **Honcho** is a separate stack: **`docker/honcho`** (same **`mcp-net`**; gateway talks to **`honcho_api`** by name).

Operated on homestation as systemd unit **`hermes`** (requires **`box.mount`** and **`honcho.service`**).

---

## Host mount points

| Host path | Container path |
| --------- | -------------- |
| **`~/.hermes`** | `/opt/data` |
| **`/box`** | `/box` |

---

## Initial setup

1. **Host directories**: **`~/.hermes`** and mounted **`/box`** (NixOS `fileSystems."/box"`).

2. **Honcho must be running** on **`mcp-net`** before Hermes (handled by systemd **`After=`** / **`Requires=`**). Configure Honcho in **`docker/honcho/`**.

3. From **`docker/hermes/`** (images pull automatically):

   ```bash
   docker compose pull
   ```

---

## Environment file

There is **no** `.env` beside **`docker/hermes/compose.yaml`**. **`HERMES_UID`** / **`HERMES_GID`** are set in compose for user **`liempo`** (`1000` / `100`).
