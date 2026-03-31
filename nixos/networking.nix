{ config, pkgs, ... }:

let
  domain = "homestation.airplane-skilift.ts.net";
  tsCertDir = "/var/lib/tailscale/certs";
  nginxCertDir = "/var/lib/nginx/ssl";
in
{
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

  # Ensure nginx has a readable place for certs/keys (nginx runs with ProtectHome=true).
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

      locations."/" = {
        return = "301 https://$host$request_uri";
      };
    };
  };
}
