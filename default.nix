self: super:

let
  callPackage = super.callPackage;

in {
  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  nhc = callPackage ./pkgs/nhc {};

  targetisns = callPackage ./pkgs/targetisns {};

  redfishtool = callPackage ./pkgs/redfishtool {};
}

