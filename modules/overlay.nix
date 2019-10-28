{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./countryfw.nix
    ./orangefs-client.nix
    ./orangefs-server.nix
    ./inituser.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
}
