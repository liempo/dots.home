# Stremio server

Single-container **`stremio/server`** stack. Operated on homestation as systemd unit **`stremio`**.

---

## Host mount points

**None** in **`compose.yaml`** — the image runs without host bind mounts (ephemeral container filesystem only).

---

## Initial setup

None beyond Docker; from **`docker/stremio/`**:

```bash
docker compose pull
```

---

## Environment file

There is **no** `.env` file. **`NO_CORS=1`** is set in **`compose.yaml`**.
