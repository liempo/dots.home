{ config, ... }:

{
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.hostUsers = [ "liempo" ];
    addToSystemPackages = true;
    configFile = ./config.yaml;
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    authFile = config.sops.secrets."hermes-auth".path;
  };
}
