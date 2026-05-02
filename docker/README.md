# Docker stacks

Compose stacks under **`docker/`** on **homestation**. **systemd** starts them from `~/.dots/docker/<stack>/` (see `system/services.nix`).

Each subdirectory has a **`README.md`** with **initial setup** and **`.env`** only.

---

## Shared MCP network

Stacks declare a Docker network named **`mcp-net`** (`name: mcp-net`). Containers on **`mcp-net`** reach each other by DNS name (for example `http://chronos-mcp:8000/mcp`, `http://honcho_api:8000`, `http://jira-mcp:8000/mcp`).

---

## Exposure summary

“**Host**” means the NixOS machine. **`0.0.0.0`** is all interfaces; **`127.0.0.1`** is loopback only. **`mcp-net only`** means no port is published on the host; only other containers on **`mcp-net`** can connect.

### `calendar`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `radicale` | `127.0.0.1:5232` | no |
| `chronos-mcp` | *(none)* | yes — HTTP MCP on container port **8000** (`chronos-mcp:8000`) |
| `sync-personal`, `sync-astra`, `sync-tonic` | *(none)* | yes |

### `honcho`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `honcho_api` | *(none)* | yes — **`honcho_api:8000`** |
| `honcho_deriver` | *(none)* | no |
| `honcho_database` | *(none)* | no |
| `honcho_redis` | *(none)* | no |

### `hermes`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `hermes` | `0.0.0.0:8642` | yes |
| `hermes-dashboard` | `0.0.0.0:9119` | no (default compose network only) |

### `stremio`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `stremio` | `127.0.0.1:11470` | no |

### `jira`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `jira-tickets-mcp` (`jira-mcp`) | *(none)* | yes — streamable HTTP MCP on **8000** (`/mcp`) |
| `jira-attachments-mcp` | *(none)* | yes — same |

### `kdbx`

| Service | Host | `mcp-net` |
| ------- | ---- | --------- |
| `kdbx-mcp` | *(none)* | yes — HTTP MCP on **8000** (`/mcp`) |
