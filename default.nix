self: super:

let
  callPackage = super.callPackage;

in {
  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  redfishtool = callPackage ./pkgs/redfishtool {};
}

