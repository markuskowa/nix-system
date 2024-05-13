pkgs:

let
  inherit (pkgs) callPackage lib;

in {
  enroot = pkgs.pkgsMusl.callPackage ./pkgs/enroot {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  nhc = callPackage ./pkgs/nhc {};

  redfishtool = callPackage ./pkgs/redfishtool {};

  slurm-spank-pyxis = callPackage ./pkgs/slurm-spank-pyxis {};

  formats = pkgs.formats // {
    keyValueCustom = import ./pkgs/formater { inherit pkgs lib; };
  };
}

