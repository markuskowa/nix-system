self: super:

let
  callPackage = super.callPackage;

in {
  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  nhc = callPackage ./pkgs/nhc {};

  redfishtool = callPackage ./pkgs/redfishtool {};

  slurm-spank-stunnel = callPackage ./pkgs/slurm-spank-stunnel {};

  formats = super.formats // {
    keyValue = import ./pkgs/formater { inherit (super) pkgs lib; };
  };

  beegfs = callPackage ./pkgs/beegfs { };

  linuxPackages = super.linuxPackages // {
    beegfs = super.linuxPackages.callPackage ./pkgs/beegfs/module.nix { };
  };

  beegfs-modules = self.linuxPackages.callPackage ./pkgs/beegfs/module.nix { };
}

