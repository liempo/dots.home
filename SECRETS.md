# Secrets (SOPS + sops-nix) — setup

This is the **step-by-step** setup for:

- **Homestation** decrypts at boot/activation (host-owned key).
- **You** can edit `secrets/secrets.yaml` without `sudo` (personal key).

The encrypted file is `secrets/secrets.yaml`. Recipient rules live in `.sops.yaml`.

## One-time setup (homestation)

### 1) Generate homestation host recipient (public)

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
```

Copy the `age1...` output.

### 2) Create an age identity file for the host (private)

This repo’s homestation setup decrypts reliably using `SOPS_AGE_KEY_FILE` (not by pointing SOPS directly at the SSH key).

```bash
sudo install -d -m 0700 /var/lib/sops-nix
sudo nix run nixpkgs#ssh-to-age -- \
  -private-key \
  -i /etc/ssh/ssh_host_ed25519_key \
  -o /var/lib/sops-nix/age-keys.txt
sudo chmod 0400 /var/lib/sops-nix/age-keys.txt
```

### 3) Test host decryption (must print OK)

```bash
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/age-keys.txt \
  nix run nixpkgs#sops -- -d secrets/secrets.yaml >/dev/null && echo OK
```

## One-time setup (your user, for editing)

### 4) Create your personal age identity file (private)

```bash
mkdir -p ~/.config/sops/age
nix run nixpkgs#ssh-to-age -- \
  -private-key \
  -i ~/.ssh/id_ed25519_personal \
  -o ~/.config/sops/age/personal-keys.txt
chmod 0400 ~/.config/sops/age/personal-keys.txt
```

### 5) Print your personal recipient (public)

```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/personal-keys.txt
```

Copy the `age1...` output.

## Repo changes (recipients)

### 6) Add both recipients to `.sops.yaml`

In `.sops.yaml` under the rule for `secrets/secrets.yaml`, include:

- the **personal recipient** (Step 5)
- the **homestation host recipient** (Step 1)

### 7) Rewrap `secrets/secrets.yaml` to match `.sops.yaml`

This step requires a working identity for the file; on homestation use the host identity:

```bash
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/age-keys.txt \
  nix run nixpkgs#sops -- updatekeys -y secrets/secrets.yaml
```

## Day-to-day

### Edit secrets (no sudo)

```bash
env SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/personal-keys.txt \
  nix run nixpkgs#sops -- secrets/secrets.yaml
```

### Decrypt as root on homestation (debug)

```bash
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/age-keys.txt \
  nix run nixpkgs#sops -- -d secrets/secrets.yaml | head
```

## How NixOS passes secrets to services (quick)

- `system/sops/sops.nix` points `sops-nix` at `system/sops/secrets.yaml` and declares secrets (e.g. `hermes-env`, `hermes-auth`, **`calendar-env`**).
- `sops-nix` materializes them as files (typically under `/run/secrets/...`).
- Hermes: `system/hermes/hermes.nix` uses `config.sops.secrets."<name>".path`.
- Calendar Compose: `system/services.nix` — **`calendar-env`** is the `calendar.service` `EnvironmentFile`.

## Recovery (short)

### Lost personal editing key

Create a new personal identity/recipient, add it to `.sops.yaml`, then:

```bash
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/age-keys.txt \
  nix run nixpkgs#sops -- updatekeys -y secrets/secrets.yaml
```

### Lost all identities (no one can decrypt)

You cannot decrypt old secrets. Recovery = **rotate credentials upstream** (recreate API keys/tokens) and create a fresh `secrets/secrets.yaml` encrypted to new recipients.
