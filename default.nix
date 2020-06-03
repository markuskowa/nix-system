self: super:

let
  callPackage = super.callPackage;

in {
  nfs-ganesha = callPackage ./pkgs/nfs-ganesha {};

  ntirpc = callPackage ./pkgs/ntirpc {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  redfishtool = callPackage ./pkgs/redfishtool {};
}

