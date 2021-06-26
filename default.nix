self: super:

let
  callPackage = super.callPackage;

in {
  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  nhc = callPackage ./pkgs/nhc {};

  redfishtool = callPackage ./pkgs/redfishtool {};

  formats = super.formats // {
    keyValue = import ./pkgs/formater { inherit (super) pkgs lib; };
  };
}

