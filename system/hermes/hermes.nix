{ config, ... }:

{
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.hostUsers = [ "liempo" ];
    container.image = "hermes-agent:local";
    addToSystemPackages = true;
    configFile = ./config.yaml;
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    authFile = config.sops.secrets."hermes-auth".path;
  };
}
