{ config, pkgs, ... }:

{

  # ── Bootloader ─────────────────────────────────────────────────────────

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.extraModprobeConfig = ''
    options snd_hda_intel index=1
  '';


# ── System ───────────────────────────────────────────────────────────────

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "Asia/Manila";
  i18n.defaultLocale = "en_PH.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ALL = "en_US.UTF-8";
    LC_NUMERIC="en_PH.UTF-8";
    LC_TIME="en_PH.UTF-8";
    LC_COLLATE="en_PH.UTF-8";
    LC_MONETARY="en_PH.UTF-8";
    LC_MESSAGES="en_PH.UTF-8";
    LC_PAPER="en_PH.UTF-8";
    LC_NAME="en_PH.UTF-8";
    LC_ADDRESS="en_PH.UTF-8";
    LC_TELEPHONE="en_PH.UTF-8";
    LC_MEASUREMENT="en_PH.UTF-8";
    LC_IDENTIFICATION="en_PH.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.liempo = {
    isNormalUser = true;
    description = "Liempo";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    packages = with pkgs; [
      tmux zoxide neovim
      nodejs docker-compose 
    ];
    shell = pkgs.zsh;
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "liempo";

  # List packages installed in system profile. 
  environment.systemPackages = with pkgs; [
    git zsh
  ];
  environment.variables.EDITOR = "nvim";

# ── Services ────────────────────────────────────────────────────────────

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # Virtualization with Docker
  virtualisation.docker.enable = true;

  # ── Program config ──────────────────────────────────────────────────────

  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = ["git"];
      theme = "fino";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
