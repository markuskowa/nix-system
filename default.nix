self: super:

let
  callPackage = super.callPackage;

in {
  enroot = callPackage ./pkgs/enroot {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  nhc = callPackage ./pkgs/nhc {};

  redfishtool = callPackage ./pkgs/redfishtool {};

  slurm-spank-stunnel = callPackage ./pkgs/slurm-spank-stunnel {};

  slurm-spank-pyxis = callPackage ./pkgs/slurm-spank-pyxis {};

  formats = super.formats // {
    keyValueCustom = import ./pkgs/formater { inherit (super) pkgs lib; };
  };

  beegfs = callPackage ./pkgs/beegfs { };

  linuxPackages_5_10 = super.linuxPackages_5_10 // {
    beegfs = super.linuxPackages_5_10.callPackage ./pkgs/beegfs/module.nix { };
  };

  beegfs-modules = self.linuxPackages_5_10.callPackage ./pkgs/beegfs/module.nix { };
}

