{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./countryfw.nix
    ./infiniband.nix
    ./moosefs.nix
    ./nfs-ganesha.nix
    ./orangefs-client.nix
    ./orangefs-server.nix
    ./inituser.nix
    ./banner.nix
    ./networkmap.nix
    ./zfs-attrs.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
}
