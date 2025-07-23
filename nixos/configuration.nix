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
  boot.extraModprobeConfig = ''
    options snd_hda_intel index=1
  '';

  networking.hostName = "homestation";

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

  # Hardware
  hardware.alsa.enablePersistence = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.liempo = {
    isNormalUser = true;
    description = "Liempo";
    extraGroups = [ "wheel" "networkmanager" "docker" "audio" ];
    packages = with pkgs; [
      fzf ripgrep stow tmux zoxide
      alsa-utils pulseaudio nqptp shairport-sync
      fastfetch cava
    ];
    shell = pkgs.zsh;
  };

  # Enable automatic login for the user.
  services.getty.autologinUser = "liempo";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git wget zsh neovim docker-compose 
  ];

  environment.variables.EDITOR = "neovim";

  ### Services

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # Pipewire services and other audio services
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # MDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  # Virtualization with Docker
  virtualisation.docker.enable = true;

  # Samba 
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Homestation";
        "netbios name" = "Homestation";
        "security" = "user";
        "hosts allow" = "192.168.0. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      "home" = {
        "path" = "/home/liempo";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "liempo";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  ### Systemd

  systemd.services = {
    nqptp = {
      description = "Network Precision Time Protocol for Shairport Sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nqptp}/bin/nqptp";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };

  systemd.user.services = {
    shairport-sync = {
      description = "AirPlay 2 functionality";
      wantedBy = [ "default.target" ];
      after       = [ "pipewire-pulse.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.shairport-sync-airplay2}/bin/shairport-sync -c /etc/shairport-sync.conf";
        Restart          = "on-failure";
        RuntimeDirectory = "shairport-sync";
      };
    };
  };

  ### Environment config
  environment.etc."shairport-sync.conf".text = ''
    general =
    {
      name = "Office Speakers";
      output_backend = "pa";
      port = 7000;
      airplay_device_id_offset = 0;
    };
    pa =
    {
    	application_name = "Shairport Sync";
      sink = "alsa:acp:Generic_1:3:playback"
    };
    diagnostics =
    {
      log_verbosity = 1;
    };
  '';

  ### Program config

  programs.zsh = {
    enable = true;
    shellAliases = {
      dots = "nvim ~/.dots";
      update = "sudo nixos-rebuild switch";
    };
    ohMyZsh = {
      enable = true;
      plugins = ["git"];
      theme = "fino";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.firewall.allowPing = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
