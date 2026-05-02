# Honcho stack

FastAPI **`honcho_api`**, background **`honcho_deriver`**, Postgres (**pgvector**), and Redis. Runs as its own Compose project under **`docker/honcho`**. **`honcho_api`** stays on **`mcp-net`** so **`hermes`** and other MCP peers resolve **`http://honcho_api:8000`**.

Operated on homestation as systemd unit **`honcho`** (no **`/box`** dependency).

---

## Host mount points

| Host / Docker | Container path | Notes |
| ------------- | -------------- | ----- |
| **`docker/honcho/src/database/init.sql`** (repo path; `./src/database/init.sql` in this directory) | `/docker-entrypoint-initdb.d/init.sql` | Postgres first-run init |
| **`honcho_pgdata`** (named volume) | `/var/lib/postgresql/data/` | Postgres data |
| **`honcho_redis_data`** (named volume) | `/data` | Redis persistence |


## Initial setup

1. **Submodule**

   ```bash
   git submodule update --init --recursive docker/honcho/src
   ```

2. **Environment file**

   ```bash
   cp src/.env.template .env
   ```

   Edit **`docker/honcho/.env`**. Compose sets **`DB_CONNECTION_URI`** and **`CACHE_URL`** in **`environment:`**; follow the template for **LLM** keys (`LLM_OPENAI_COMPATIBLE_*` or alternatives), **`AUTH_USE_AUTH`**, etc.

3. **First build** (from **`docker/honcho/`**):

   ```bash
   docker compose build
   ```

---

## Environment file

Secrets and Honcho tuning live in **`docker/honcho/.env`** (gitignored). **`systemd.services.hermes`** is ordered **after** **`honcho.service`** so the gateway starts once **`honcho_api`** is up.
