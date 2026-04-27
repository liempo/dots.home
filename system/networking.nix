{ config, ... }:

{

  networking.hostName = "homestation";
  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [
    22
    config.homestation.tonic_vm.playwright_port
  ];

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

}
