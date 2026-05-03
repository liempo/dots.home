{ config, pkgs, inputs, ... }:

let
  root = ../.;
  dotconfig = ./.; # not to be confused with NixOS configuration
  # Hermes alias to containerized Hermes agent 
  hermes = pkgs.writeShellScriptBin "hermes" ''
    exec docker run -it --rm \
      --network mcp-net \
      --add-host=host.docker.internal:host-gateway \
      -e HERMES_UID="$(id -u)" \
      -e HERMES_GID="$(id -g)" \
      -v "$HOME/.hermes:/opt/data" \
      nousresearch/hermes-agent "$@"
  '';
  # Helper to rebuild the system
  update = pkgs.writeShellScriptBin "update" ''
    exec sudo nixos-rebuild switch --flake "$HOME/.dots#homestation"
  '';
in
{
  imports = [ inputs."sops-nix".homeManagerModules.default ];

  home.username = "liempo";
  home.homeDirectory = "/home/liempo";
  home.stateVersion = "24.11";

  sops = {
    defaultSopsFile = root + "/secrets/default.yaml";
    age.keyFile = "${config.home.homeDirectory}/.dots/secrets/host.age.key";
    secrets.honcho_env = {
      path = "${config.home.homeDirectory}/.dots/docker/honcho/.env";
      mode = "0600";
    };
    secrets.radicale_env = {
      sopsFile = root + "/secrets/calendar.yaml";
      path = "${config.home.homeDirectory}/.dots/docker/calendar/.env";
      mode = "0600";
    };
    secrets.jira_env = {
      sopsFile = root + "/secrets/tonic.yaml";
      path = "${config.home.homeDirectory}/.dots/docker/jira/.env";
      mode = "0600";
    };
    secrets.kdbx_env = {
      sopsFile = root + "/secrets/tonic.yaml";
      path = "${config.home.homeDirectory}/.dots/docker/kdbx/.env";
      mode = "0600";
    };
  };

  home.packages = [
    update
    hermes
    pkgs.sops
  ];
  home.file.".zshrc".source = "${dotconfig}/.zshrc";

  programs.git.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile "${dotconfig}/.config/tmux/tmux.conf";
  };

  xdg.configFile = {
    "nvim".source = "${dotconfig}/.config/nvim";
  };
}

