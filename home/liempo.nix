{ config, pkgs, ... }:

let
  dotfiles = ./.;
  # Hermes alias to containerized Hermes agent 
  hermes = pkgs.writeShellScriptBin "hermes" ''
    exec docker run -it --rm \
      -v "$HOME/.hermes:/opt/data" \
      nousresearch/hermes-agent "$@"
  '';
  # Helper to rebuild the system
  update = pkgs.writeShellScriptBin "update" ''
    exec sudo nixos-rebuild switch --flake "$HOME/.dots#homestation"
  '';
in
{
  home.username = "liempo";
  home.homeDirectory = "/home/liempo";
  home.stateVersion = "24.11";

  home.packages = [ update hermes ];
  home.file.".zshrc".source = "${dotfiles}/.zshrc";

  programs.git.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile "${dotfiles}/.config/tmux/tmux.conf";
  };

  xdg.configFile = {
    "nvim".source = "${dotfiles}/.config/nvim";
  };
}

