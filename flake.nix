{
  description = "NixOS + Home Manager (homestation)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = { 
    self,
    nixpkgs,
    home-manager,
    hermes-agent,
    sops-nix,
    ...
   }:
    {
      nixosConfigurations = {
        homestation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nixos/configuration.nix
            ./nixos/networking.nix
            ./nixos/hermes.nix

            sops-nix.nixosModules.sops
            hermes-agent.nixosModules.default

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";
              home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
              home-manager.users.liempo = import ./home/liempo.nix;
            }
          ];
        };
      };
    };
}

