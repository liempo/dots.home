{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "hermes-env" = {
        owner = "hermes";
        group = "hermes";
        mode = "0440";
      };

      "hermes-auth" = {
        owner = "hermes";
        group = "hermes";
        mode = "0440";
      };
    };
  };
}
