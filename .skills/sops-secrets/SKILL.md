---
name: sops-secrets
description: >-
  Full workflow for SOPS-encrypted secrets under secrets/*.yaml with age and the
  gitignored key secrets/host.age.key; Home Manager materialization via
  home/liempo.nix. Use for sops, age, host.age.key, secrets/*.yaml, sops-nix,
  or editing encrypted env/JSON for this flake.
---

# SOPS secrets (.dots)

Encrypted YAML lives under **`secrets/`**. [Mozilla SOPS](https://github.com/getsops/sops) uses **age**; the private key is **`secrets/host.age.key`** (gitignored—never commit it). This file is the single reference for humans and agents.

## Prerequisites

- **`sops`** on PATH (Home Manager here installs `pkgs.sops`; otherwise `nix-shell -p sops`).
- **`~/.dots/secrets/host.age.key`** readable, matching the **public** age recipient in [`.sops.yaml`](../../.sops.yaml) (`path_regex: secrets/.*\.yaml$`).

If decrypt fails, set the key explicitly (adjust if your clone is not `~/.dots`):

```bash
export SOPS_AGE_KEY_FILE="$HOME/.dots/secrets/host.age.key"
```

## Encrypted files → Home Manager → disk

Authoritative wiring is [`home/liempo.nix`](../../home/liempo.nix) (`sops.secrets.*`). Each `secrets/*.yaml` **top-level key** must match the secret name expected by sops-nix for that file.

| `secrets/` file | Secret name(s) in YAML | Output path |
|-----------------|------------------------|-------------|
| [`secrets/default.yaml`](../../secrets/default.yaml) | `honcho_env` | `~/.dots/docker/honcho/.env` |
| [`secrets/calendar.yaml`](../../secrets/calendar.yaml) | `radicale_env`, `chronos_accounts_json`, `google_oauth_client_json` | `~/.calendar/radicale/.env`, `~/.calendar/chronos/accounts.json`, `~/.calendar/google/oauth.json` |
| [`secrets/tonic.yaml`](../../secrets/tonic.yaml) | `jira_env`, `kdbx_env` | `~/.dots/docker/jira/.env`, `~/.dots/docker/kdbx/.env` |

Calendar keys all live in [`secrets/calendar.yaml`](../../secrets/calendar.yaml); edit that file only (no separate OAuth file).

## Edit workflow

1. Set `SOPS_AGE_KEY_FILE` when needed.
2. From the repo root:

   ```bash
   sops secrets/<name>.yaml
   ```

3. Commit updated `secrets/*.yaml` only—not `host.age.key`, not generated `.env` / JSON under `~/.calendar` or `~/.dots/docker/` unless you intentionally version those (this repo generally does not).

4. On the host that applies config, rebuild so secrets are materialized:

   ```bash
   sudo nixos-rebuild switch --flake "$HOME/.dots#homestation"
   ```

## Optional: decrypt / edit / encrypt

```bash
export SOPS_AGE_KEY_FILE="$HOME/.dots/secrets/host.age.key"
sops -d secrets/calendar.yaml > /tmp/calendar.plain.yaml
# edit /tmp/calendar.plain.yaml, then from ~/.dots (so `.sops.yaml` applies):
cp /tmp/calendar.plain.yaml secrets/calendar.yaml && sops -e -i secrets/calendar.yaml
rm -f /tmp/calendar.plain.yaml
```

Prefer in-place `sops secrets/...` when you can.

## New machine or new key

- Restore **`secrets/host.age.key`** from a secure backup, or generate a new age key, update [`.sops.yaml`](../../.sops.yaml) if the canonical recipient changes, and **re-key** every `secrets/*.yaml` with `sops`.

## Safety

- Do not paste plaintext secrets into issues, chat, or git history.
- Keep `host.age.key` permissions tight (`0600`).
