{ config, pkgs, ... }:

let
  dotfiles = ./.;
in
{
  home.username = "liempo";
  home.homeDirectory = "/home/liempo";
  home.stateVersion = "24.11";

  home.file.".zshrc".source = "${dotfiles}/.zshrc";
  home.file."calendar".source = "${dotfiles}/calendar";
  home.file."nginx".source = "${dotfiles}/nginx";
  home.file."compose.yaml".source = "${dotfiles}/compose.yaml";

  programs.git.enable = true;


  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile "${dotfiles}/.config/tmux/tmux.conf";
  };

  xdg.configFile = {
    "nvim".source = "${dotfiles}/.config/nvim";
  };
}

