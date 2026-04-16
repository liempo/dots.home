{ config, pkgs, ... }:

let
  domain = "homestation.airplane-skilift.ts.net";
  tsCertDir = "/var/lib/tailscale/certs";
  nginxCertDir = "/var/lib/nginx/ssl";
in
{
  networking.hostName = "homestation";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 22 ];

  # ── Tailscale ──────────────────────────────────────────────────────────

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

  # ── Nginx ──────────────────────────────────────────────────────────────

  systemd.tmpfiles.rules = [
    "d ${nginxCertDir} 0750 root nginx -"
  ];


  # One-shot: copy Tailscale certs into nginx-readable directory.
  # Prereq: `sudo tailscale cert ${domain}` to create files in ${tsCertDir}.
  systemd.services.tailscale-nginx-sync = {
    description = "Sync Tailscale certs for nginx";
    wantedBy = [ "nginx.service" ];
    before = [ "nginx.service" ];
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
    };
    script = ''
      set -euo pipefail
      install -d -m 0750 -o root -g nginx "${nginxCertDir}"
      install -m 0640 -o root -g nginx "${tsCertDir}/${domain}.crt" \
        "${nginxCertDir}/${domain}.crt"
      install -m 0640 -o root -g nginx "${tsCertDir}/${domain}.key" \
        "${nginxCertDir}/${domain}.key"
    '';
  };


  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."${domain}" = {
      addSSL = true;
      listen = [
        { addr = "0.0.0.0"; port = 80; }
        { addr = "0.0.0.0"; port = 443; ssl = true; }
        { addr = "[::]"; port = 80; }
        { addr = "[::]"; port = 443; ssl = true; }
      ];

      sslCertificate = "${nginxCertDir}/${domain}.crt";
      sslCertificateKey = "${nginxCertDir}/${domain}.key";

      locations."= /calendar" = {
        return = "301 https://$host/calendar/";
      };

      locations."/calendar/" = {
        proxyPass = "http://127.0.0.1:5232/";
        extraConfig = ''
          proxy_set_header X-Script-Name /calendar;
          proxy_pass_header Authorization;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 300s;
        '';
      };

      locations."= /.well-known/caldav" = {
        return = "301 https://$host/calendar/";
      };
      locations."= /.well-known/carddav" = {
        return = "301 https://$host/calendar/";
      };

      # Hermes dashboard (docker/hermes: dashboard listens on 9119)
      locations."/hermes/" = {
        proxyPass = "http://127.0.0.1:9119/";
        extraConfig = ''
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_read_timeout 300s;
        '';
      };
    };
  };
}
