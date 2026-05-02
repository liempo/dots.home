{ config, ... }:

let
  inherit (config.homestation) tonic_vm;
in
{

  # Reverse-proxy Playwright / MCP on `tonic` (libvirt NAT). Docker `mcp-net` and other
  # clients reach the VM via homestation:8931 instead of 192.168.122.x directly.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."tonic-mcp" = {
      serverName = "_";
      http2 = false;
      extraConfig = "gzip off;";
      listen = [
        {
          addr = "0.0.0.0";
          port = tonic_vm.playwright_port;
          ssl = false;
        }
      ];
      locations."/" = {
        proxyPass = "http://${tonic_vm.ip}:${toString tonic_vm.playwright_port}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_buffering off;
          proxy_cache off;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
          proxy_set_header Connection "";
        '';
      };
    };
  };

}
