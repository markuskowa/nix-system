self: super:

let
  callPackage = super.callPackage;

in {
  orangefs = callPackage ./pkgs/orangefs {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  redfishtool = callPackage ./pkgs/redfishtool {};
}

