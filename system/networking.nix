{

  networking.hostName = "homestation";
  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 ];

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
}
