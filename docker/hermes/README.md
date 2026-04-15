# Hermes — custom baked OCI image

The NixOS **`services.hermes-agent`** module can run Hermes as a **Docker** container on the host (`container.enable = true`). By default you point **`container.image`** at an image tag on your machine.

This folder holds a **Dockerfile** you can use to **bake extra tools** into that base filesystem (for example **Node**, **agent-browser**, and Chrome via `agent-browser install --with-deps`) so they still exist after the container is recreated—unlike installing packages only inside a running container.

The module still supplies the **runtime entrypoint** (`/data/current-entrypoint`); your image is only the **base OS + whatever you add**.

## Build

From the **repository root** (`~/.dots`):

```bash
docker build -t hermes-agent:local -f docker/hermes/Dockerfile docker/hermes
```

This tags the image as **`hermes-agent:local`**, which matches the default in `system/hermes/hermes.nix`.

## NixOS wiring

In **`system/hermes/hermes.nix`**, set:

```nix
services.hermes-agent.container.image = "hermes-agent:local";
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake ~/.dots#homestation
```

Restart or recreate the Hermes container as needed (the exact unit names come from the **hermes-agent** module).

## Editing the Dockerfile

Adjust **`docker/hermes/Dockerfile`** for your needs (extra packages, pinned versions, etc.), then **rebuild** the image and restart the agent so Docker picks up the new layers.

## Upstream

- Hermes agent module / behavior: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
