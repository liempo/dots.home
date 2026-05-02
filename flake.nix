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
  };

  outputs =
    inputs@{ self, nixpkgs, home-manager, ... }:
    {
      nixosConfigurations = {
        homestation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./system/hardware.nix
            ./system/configuration.nix
            ./system/libvirt.nix
            ./system/nginx.nix
            ./system/networking.nix
            ./system/services.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.liempo = import ./home/liempo.nix;
            }
          ];
        };
      };
    };
}
