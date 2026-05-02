# Jira MCP stack

Two streamable-HTTP MCP services on **`mcp-net`** (tickets + attachments). Operated on homestation as systemd unit **`jira`** (requires **`box.mount`**).

---

## Host mount points

| Host path | Container path | Service |
| --------- | -------------- | ------- |
| **`/box/tonic/attachments`** | `/box/tonic/attachments` | `jira-attachments-mcp` only |

**`jira-tickets-mcp`** has no bind mounts (API-only).

---

## Initial setup

Ensure the attachments download directory exists on the host:

```bash
mkdir -p /box/tonic/attachments
```

From **`docker/jira/`**:

```bash
docker compose build
```

---

## Environment file

```bash
cp .env.example .env
```

Edit **`docker/jira/.env`**:

| Variable | Purpose |
| -------- | ------- |
| `JIRA_BASE_URL` | Cloud URL, e.g. `https://yourcompany.atlassian.net` |
| `JIRA_EMAIL` | Atlassian account email |
| `JIRA_API_TOKEN` | From Atlassian → Security → API tokens |

Both **`jira-tickets-mcp`** and **`jira-attachments-mcp`** read this file; the attachments service also sets **`DEFAULT_DOWNLOAD_PATH=/box/tonic/attachments`** in compose.
