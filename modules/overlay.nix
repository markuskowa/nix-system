{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./countryfw.nix
    ./orangefs-client.nix
    ./orangefs-server.nix
    ./inituser.nix
    ./banner.nix
    ./networkmap.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
}
