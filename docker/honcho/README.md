# Honcho stack (API + deriver + Postgres + Redis)

This directory defines the **Honcho** memory stack for homestation via **`compose.yaml`**. The API and deriver **build from the Git submodule** at **`./src`** (`plastic-labs/honcho`).

## Submodule

Initialize if missing:

```bash
git submodule update --init --recursive
```

## Configuration

- **Database / Redis**: Defaults in `compose.yaml` (Postgres on **`127.0.0.1:5432`**, Redis on **`127.0.0.1:6379`**).
- **Optional env**: Create **`./.env`** next to `compose.yaml` for API keys and app settings (gitignored). Compose references it with `required: false`.

## systemd

**`honcho.service`** runs `docker compose -f compose.yaml up` from this directory (see `system/services.nix`).

- Logs: `journalctl -u honcho -f`
- After changing the submodule or Dockerfiles: `docker compose build` then `sudo systemctl restart honcho`

## API URL

The API is published on **`0.0.0.0:8000`** on the host. Other containers (for example Hermes) can reach it via the **host** network address if configured in those apps.

## Upstream docs

Application behavior, environment variables, and development workflows are documented in the submodule: **`src/README.md`**.
