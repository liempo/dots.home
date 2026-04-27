{ config, lib, pkgs, ... }:

let
  dotsDir = "${config.users.users.liempo.home}/.dots";
  compose = "${pkgs.docker-compose}/bin/docker-compose";
in

{
  systemd.services.calendar = {
    description = "Calendar stack — Radicale + sync (Docker Compose)";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5";
      User = "liempo";
      WorkingDirectory = "${dotsDir}/docker/calendar";
      ExecStart = "${compose} -f compose.yaml up --remove-orphans";
      ExecStop = "${compose} -f compose.yaml down";
      TimeoutStopSec = "120";
    };
  };

  systemd.services.stremio = {
    description = "Stremio streaming server (Docker Compose)";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5";
      User = "liempo";
      WorkingDirectory = "${dotsDir}/docker/stremio";
      ExecStart = "${compose} -f compose.yaml up --remove-orphans";
      ExecStop = "${compose} -f compose.yaml down";
      TimeoutStopSec = "120";
    };
  };

  systemd.services.hermes = {
    description = "Hermes agent stack (Docker Compose)";
    after = [ "network-online.target" "docker.service" "box.mount" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "box.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5";
      User = "liempo";
      WorkingDirectory = "${dotsDir}/docker/hermes";
      ExecStart = "${compose} -f compose.yaml up --remove-orphans";
      ExecStop = "${compose} -f compose.yaml down";
      TimeoutStopSec = "120";
    };
  };

  # SMB share for the /box mount (see configuration.nix fileSystems."/box").
  # After deploy: sudo smbpasswd -a liempo   # Samba password (separate from login).
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "homestation box";
        "server role" = "standalone server";
        "map to guest" = "Never";
      };
      box = {
        path = "/box";
        comment = "Box (/box)";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "liempo";
        "vfs objects" = "recycle";
        "recycle:repository" = ".recycle/%u";
        "recycle:keeptree" = "yes";
        "recycle:versions" = "yes";
        "recycle:touch" = "yes";
      };
    };
  };

  systemd.services.samba-smbd = lib.mkIf config.services.samba.enable {
    after = [ "box.mount" ];
    requires = [ "box.mount" ];
  };
}
