# Architecture

This repository is a **host configuration + self-hosted services** monorepo:

- **NixOS flake** defines a machine called **`homestation`**.
- **Home Manager** manages user-level dotfiles for `liempo`.
- **systemd services** start/stop several **Docker Compose stacks** under `docker/`.
- One stack (`docker/hermes/honcho/src`) is a **git submodule**: the upstream **Honcho** service.

---

## Repository map (high level)

```mermaid
flowchart TB
  repo["~/.dots (this repo)"]

  repo --> flake["flake.nix\n(nixosConfigurations.homestation)"]
  repo --> system["system/\nNixOS modules"]
  repo --> home["home/\nHome Manager modules"]
  repo --> docker["docker/\nDocker Compose stacks"]

  system --> cfg["configuration.nix\n(core OS config)"]
  system --> net["networking.nix\n(host networking)"]
  system --> svc["services.nix\n(systemd units for stacks)"]

  home --> hm["liempo.nix\n(user config)"]
  home --> zsh[".zshrc"]
  home --> nvim[".config/nvim/…"]

  docker --> hermes["hermes/\nHermes + Dashboard + Honcho include"]
  docker --> calendar["calendar/\nRadicale + sync workers + MCP"]
  docker --> stremio["stremio/\nStremio server"]
```

---

## “Homestation” system architecture

### Control plane: NixOS + Home Manager

- **Flake entrypoint**: `flake.nix` defines `nixosConfigurations.homestation` and includes:
  - `system/configuration.nix`
  - `system/networking.nix`
  - `system/services.nix`
  - Home Manager (`home/liempo.nix`)
- **Networking**: `system/networking.nix` sets hostname, enables NetworkManager, enables Tailscale, and opens SSH (TCP/22).
- **User**: `liempo` is created in `system/configuration.nix` and put in the `docker` group.
- **Local dotfiles** are applied by Home Manager:
  - `~/.zshrc` is sourced from this repo.
  - Neovim config is sourced from `~/.config/nvim`.
  - Convenience scripts:
    - `update`: runs `sudo nixos-rebuild switch --flake "$HOME/.dots#homestation"`
    - `hermes`: runs the Hermes agent container interactively.

### Data plane: systemd-managed Docker Compose

`system/services.nix` defines one unit per stack:

- `calendar` → `docker compose up` in `docker/calendar`
- `stremio` → `docker compose up` in `docker/stremio`
- `hermes` → `docker compose up` in `docker/hermes`

This is the main operational contract: **NixOS boots → systemd starts Docker → systemd starts each Compose stack**.

```mermaid
sequenceDiagram
  autonumber
  participant boot as NixOS boot
  participant systemd as systemd
  participant docker as Docker daemon
  participant compose as docker compose
  participant stacks as Compose stacks (calendar/stremio/hermes)

  boot->>systemd: Start system services
  systemd->>docker: Ensure docker.service is running
  systemd->>compose: ExecStart (WorkingDirectory=stack dir)
  compose->>stacks: Create/Start containers
```

---

## Docker stacks

### Hermes stack (`docker/hermes`)

`docker/hermes/compose.yaml` runs two containers and **includes** the Honcho stack:

- **`hermes`** (gateway)
  - Listens: `0.0.0.0:8642` (published as `8642:8642`)
  - Persistent host data: `~/.hermes:/opt/data`
  - Depends on `honcho_api` being started (from the included Honcho compose)
- **`dashboard`**
  - Listens: `0.0.0.0:9119` (published as `9119:9119`)
  - Reads gateway health via `GATEWAY_HEALTH_URL=http://hermes:8642`
  - Shares the same `~/.hermes` volume mount

#### Honcho as an included stack (submodule boundary)

`docker/hermes/honcho/compose.yaml` builds and runs **Honcho** (FastAPI + worker) plus data stores:

- **`honcho_api`**: FastAPI server (published to host as `127.0.0.1:8000`)
- **`honcho_deriver`**: background worker for representation/summary/dream tasks
- **`honcho_database`**: Postgres + pgvector (published to host as `127.0.0.1:5432`)
- **`honcho_redis`**: Redis (published to host as `127.0.0.1:6379`)

The Honcho application code lives in a git submodule:

- Submodule path: `docker/hermes/honcho/src`
- Upstream: `https://github.com/plastic-labs/honcho`

```mermaid
flowchart LR
  hermes["Hermes gateway\n:8642"] --> honcho_api["Honcho API\nFastAPI :8000"]
  dashboard["Hermes dashboard\n:9119"] --> hermes

  honcho_api --> pg["Postgres + pgvector\n:5432"]
  honcho_api --> redis["Redis\n:6379"]
  honcho_deriver["Honcho deriver\n(worker)"] --> pg
  honcho_deriver --> redis

  subgraph host["Host filesystem"]
    hermes_data["~/.hermes"]
    calendar_data["~/.calendar"]
  end

  hermes --- hermes_data
  dashboard --- hermes_data
```

#### Key runtime flow (Hermes ↔ Honcho)

At runtime, the important relationship is:

- Hermes needs a **memory/insights backend** (Honcho) to store and retrieve long-term context.
- Honcho splits “API request handling” from “expensive derivations” via the `honcho_deriver` worker and Redis-backed queueing.

```mermaid
sequenceDiagram
  autonumber
  participant user as User / client
  participant hermes as Hermes gateway
  participant honcho as Honcho API
  participant redis as Redis
  participant deriver as Honcho deriver
  participant pg as Postgres (pgvector)

  user->>hermes: Request / interaction
  hermes->>honcho: Store messages / ask for context
  honcho->>pg: Persist messages + session state
  honcho->>redis: Enqueue derivation work
  deriver->>redis: Consume queued tasks
  deriver->>pg: Write representations / summaries
  honcho-->>hermes: Context / insights response
```

> For deep Honcho internals (peer/session primitives, agent roles, pipelines), see the submodule’s `docker/hermes/honcho/src/CLAUDE.md` and `docker/hermes/honcho/src/README.md`.

---

### Calendar stack (`docker/calendar`)

This stack provides a **local CalDAV server** (Radicale) plus one-or-more sync workers that publish `.ics` calendars into Radicale.

Services (from `docker/calendar/compose.yaml`):

- **`radicale`**
  - Listens: `127.0.0.1:5232`
  - Persistent host config/data:
    - `~/.calendar/radicale/etc:/radicale/etc`
    - `~/.calendar/radicale/var:/radicale/var`
- **`sync-*` containers** (examples: `sync-personal`, `sync-astra`, `sync-tonic`)
  - Build context: `docker/calendar/sync`
  - Input config: `/data/calendar.json` (mounted from `~/.calendar/data/<name>/calendar.json`)
  - Behavior: periodically generate/fetch ICS and upload into Radicale via HTTP `PUT`
- **`radicale-mcp`**
  - Exposes an MCP server over HTTP (published as `8799:8000`)
  - Connects to Radicale internally via `http://radicale:5232`

```mermaid
flowchart LR
  client["CalDAV client\n(iOS/macOS/DAVx⁵/etc)"] --> radicale["Radicale\n127.0.0.1:5232"]

  subgraph syncers["Sync containers (periodic)"]
    sync_personal["sync-personal\nICS feed → Radicale"]
    sync_astra["sync-astra\nGoogle OAuth → ICS → Radicale"]
    sync_tonic["sync-tonic\nICS feed → Radicale"]
  end

  sync_personal --> radicale
  sync_astra --> radicale
  sync_tonic --> radicale

  mcp["radicale-mcp\n:8799 (host)"] --> radicale
```

Operational details and setup steps live in `docker/calendar/README.md`.

---

### Stremio stack (`docker/stremio`)

This is a minimal single-service stack:

- **`stremio/server`**
  - Listens: `127.0.0.1:11470`
  - Environment: `NO_CORS=1`

```mermaid
flowchart LR
  user["User / LAN client"] --> stremio["Stremio server\n127.0.0.1:11470"]
```

---

## Ports and host bindings

The stacks are mostly bound to loopback for safety (except Hermes gateway/dashboard which are published on all interfaces in the compose file).

- **Hermes**
  - `8642/tcp` (host bind: `0.0.0.0:8642`)
  - `9119/tcp` (host bind: `0.0.0.0:9119`)
- **Honcho**
  - `8000/tcp` (host bind: `127.0.0.1:8000`)
  - `5432/tcp` (host bind: `127.0.0.1:5432`)
  - `6379/tcp` (host bind: `127.0.0.1:6379`)
- **Calendar**
  - `5232/tcp` (host bind: `127.0.0.1:5232`)
  - `8799/tcp` (host bind: `0.0.0.0:8799` from compose; adjust if you want loopback-only)
- **Stremio**
  - `11470/tcp` (host bind: `127.0.0.1:11470`)

---

## Source-of-truth files

- **NixOS entrypoint**: `flake.nix`
- **Core OS config**: `system/configuration.nix`
- **Systemd stack units**: `system/services.nix`
- **Home Manager user config**: `home/liempo.nix`
- **Compose stacks**:
  - `docker/hermes/compose.yaml`
  - `docker/hermes/honcho/compose.yaml`
  - `docker/calendar/compose.yaml`
  - `docker/stremio/compose.yaml`
- **Stack docs**:
  - `docker/calendar/README.md`
  - Honcho submodule docs: `docker/hermes/honcho/src/README.md`, `docker/hermes/honcho/src/CLAUDE.md`

