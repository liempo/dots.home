{ config, pkgs, ... }:

{

  # ── Bootloader ─────────────────────────────────────────────────────────

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # e1000e: VerifyNVMChecksum module param; see
  # https://lkml.org/lkml/2025/3/18/1505 (Jacek Kowalski, 2025-03-18).
  # Set to 0 if the I219-V (or similar) reports invalid NVM checksum on every boot.
  boot.kernelPatches = [
    {
      name = "e1000e-VerifyNVMChecksum";
      patch = ./patches/e1000e-VerifyNVMChecksum.patch;
    }
  ];

  boot.extraModprobeConfig = ''
    options snd_hda_intel index=1
    options e1000e VerifyNVMChecksum=0
  '';

  # Persistent storage; fsType must match the actual filesystem on the partition.
  fileSystems."/box" = {
    device = "/dev/sda3";
    fsType = "ext4";
    options = [ "defaults" ];
  };


# ── System ───────────────────────────────────────────────────────────────

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "Asia/Manila";
  i18n.defaultLocale = "en_PH.UTF-8";

  i18n.extraLocaleSettings = {
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
      tmux zoxide neovim btop sqlite
      # For cursor ssh
      nodejs
      # services 
      docker-compose 
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

  # Scarf invoke /usr/bin/pgrep; NixOS only has it on PATH.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/pgrep - - - - ${pkgs.procps}/bin/pgrep"
  ];

# ── Services ────────────────────────────────────────────────────────────

  # OpenSSH daemon
  services.openssh.enable = true;

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
