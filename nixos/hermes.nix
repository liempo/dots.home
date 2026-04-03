{ config, ... }:
{
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    settings.model.default = "openai/gpt-4o-mini";
    environmentFiles = [ config.sops.secrets.hermes.path ];
    addToSystemPackages = true;
  };
}