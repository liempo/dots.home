{ config, pkgs, ... }:

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
  systemd.services.hermes = {
    description = "Hermes agent stack (Docker Compose)";
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
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
}
