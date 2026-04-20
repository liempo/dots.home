
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

Expose the Calendar MCP endpoint under `/mcp` using a path mount (declarative configuration not supported yet):
```bash
tailscale serve --bg --https=443 --set-path=/mcp 8799
```

---

## TODO

### Tonic MCPs

- [ ] Add QA testing MCP (**needs to be set up in a virtual machine**)
- [ ] Add JIRA ticket MCP (**readonly**)

### Astra MCPs

- [ ] Add Basecamp MCP

### Editor integration

- [ ] Integrate Hermes into Zed editor

