self: super:

with super;

{
  orangefs = callPackage ./pkgs/orangefs {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

}

