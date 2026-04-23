
## What this repo is

- **Host config**: NixOS flake for `homestation` + Home Manager for user `liempo`.
- **Services**: systemd-managed Docker Compose stacks under `docker/`.

If you need the big-picture topology, read `ARCHITECTURE.md` first.

---

#### Start / restart (systemd via `services.nix`)

This repo runs Docker Compose stacks via **systemd units** defined in `system/services.nix` (see `systemd.services.calendar`).

Start / restart the calendar stack:

```bash
sudo systemctl start calendar
sudo systemctl restart calendar
```

Check status / logs:

```bash
systemctl status calendar --no-pager
journalctl -u calendar -f
```

If you change `system/services.nix`, apply the NixOS config first, then restart:

```bash
update
sudo systemctl restart calendar
```

#### Tailscale Serve (expose dashboard)

Set the Tailscale Serve config to the current config:

```bash
tailscale serve set-config --all > serve.hujson
```

Expose the calendar MCP (streamable HTTP) service on the host port `8799` (path `/mcp` on that port). For Tailscale path mounts, point your client at the served URL that reaches `http://127.0.0.1:8799/mcp` (declarative configuration not supported yet). Example:

```bash
tailscale serve --bg --https=443 --set-path=/mcp 8799
```

If your MCP client uses Streamable HTTP, use `https://<tailnet-host>/mcp` when the proxy forwards the path unchanged, or `http://127.0.0.1:8799/mcp` locally.

---

## TODO

### Tonic MCPs

- [ ] Add QA testing MCP (**needs to be set up in a virtual machine**)
- [ ] Add JIRA ticket MCP (**readonly**)

### Astra MCPs

- [ ] Add Basecamp MCP

### Editor integration

- [ ] Integrate Hermes into Zed editor

