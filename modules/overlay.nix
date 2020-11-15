{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./countryfw.nix
    ./infiniband.nix
    ./iscsid.nix
    ./iscsiTarget.nix
    ./moosefs.nix
    ./nfs-ganesha.nix
    ./inituser.nix
    ./banner.nix
    ./networkmap.nix
    ./zfs-attrs.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
}
