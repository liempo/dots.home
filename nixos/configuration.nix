# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homestation"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Manila";

  # Select internationalisation properties.
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.liempo = {
    isNormalUser = true;
    description = "Liempo";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    packages = with pkgs; [
     stow fzf ripgrep thefuck tmux
    ];
    shell = pkgs.zsh;
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "liempo";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git zsh neovim docker-compose
  ];

  environment.variables.EDITOR = "neovim";

  ### Services

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # MDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish: {
      enable = true;
      addresses = true;
    };
  };

 # PipeWire
 services.pipewire = {
   enable = true;
   alsa.enable = true;
   pulse.enable = true;
   wireplumber.enable = true;
 };

  # Virtualization with Docker
  virtualisation.docker.enable = true;

  ### Programs

  programs.zsh = {
    enable = true;
    shellAliases = {
      update = "sudo nixos-rebuild switch";
    };
    ohMyZsh = {
      enable = true;
      plugins = ["git" "thefuck"];
      theme = "fino";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
