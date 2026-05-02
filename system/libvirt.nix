{ pkgs, lib, ... }:

let
  # Set `mac` to the VM NIC: `sudo virsh dumpxml tonic | rg "mac address"`
  tonic_vm = {
    mac = "52:54:00:72:4f:3c";
    ip = "192.168.122.50";
    playwright_port = 8931;
  };

  defaultNetworkXml = pkgs.writeText "libvirt-default-network.xml" ''
    <network>
      <name>default</name>
      <bridge name='virbr0'/>
      <forward/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
          <host mac='${tonic_vm.mac}' name='tonic' ip='${tonic_vm.ip}'/>
        </dhcp>
      </ip>
    </network>
  '';
in
{
  options.homestation.tonic_vm = lib.mkOption {
    description = ''
      Constants for the libvirt guest `tonic` (DHCP reservation, MCP/nginx upstream).
      Defined in this module; read elsewhere as `config.homestation.tonic_vm`.
    '';
    type = lib.types.anything;
    readOnly = true;
  };

  config = {
    homestation.tonic_vm = tonic_vm;

    virtualisation.libvirtd.enable = true;

    systemd.services.libvirt-default-network-static-dhcp = {
      description = "Install libvirt default NAT XML (static DHCP lease for tonic)";
      after = [ "libvirtd-config.service" ];
      before = [ "libvirtd.service" ];
      script = ''
        install -D -m 644 ${defaultNetworkXml} /var/lib/libvirt/qemu/networks/default.xml
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.libvirtd = {
      requires = [ "libvirt-default-network-static-dhcp.service" ];
      after = [ "libvirt-default-network-static-dhcp.service" ];
    };

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
  };
}
