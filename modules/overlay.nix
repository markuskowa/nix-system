{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./countryfw.nix
    ./orangefs-client.nix
    ./orangefs-server.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
}
