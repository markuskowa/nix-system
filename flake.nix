{
  description = "";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let

    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: function nixpkgs.legacyPackages.${system});

  in {

    overlays.default = import ./default.nix;

    packages = forAllSystems (pkgs: import ./packages.nix pkgs);

    nixosModules = {
      default = import ./modules/overlay.nix;
    } // (import ./modules/allmodules.nix);
  };
}
