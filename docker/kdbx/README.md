# KeePass KDBX MCP

HTTP MCP for a read-only `.kdbx` vault on **`mcp-net`**. Operated on homestation as systemd unit **`kdbx`** (requires **`box.mount`**).

---

## Host mount points

| Host path | Container path | Notes |
| --------- | -------------- | ----- |
| **`/box/tonic/vault`** | `/data/vault` | Read-only; **`KDBX_PATH`** must be under `/data/vault/…` in the container |

---

## Initial setup

Ensure the vault directory exists on the host (compose mounts it read-only):

```bash
mkdir -p /box/tonic/vault
# place the .kdbx file there (name must match KDBX_PATH inside the container)
```

From **`docker/kdbx/`**:

```bash
docker compose build
```

---

## Environment file

```bash
cp .env.example .env
```

Edit **`docker/kdbx/.env`**:

| Variable | Purpose |
| -------- | ------- |
| `KDBX_PATH` | Path **inside the container**, e.g. `/data/vault/passbolt.kdbx` (under the `/box/tonic/vault` bind mount) |
| `KDBX_PASSWORD` | Vault password (if used) |
| `KDBX_KEYFILE` | Optional keyfile path inside the container |
| `KDBX_ALLOW_PASSWORD_EXPORT` | Set to `1` only if MCP responses may include decrypted passwords |

See **`.env.example`** for comments.
