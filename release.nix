{ nixpkgs ? (import <nixpkgs>) { overlays = [ (import ./default.nix) ]; } } :

let
  handleTest = t: (import <nixpkgs/nixos/tests/make-test.nix>) (import t);

in {
  # Evaluate overlay packages
  inherit (nixpkgs)
    orangefs
    ipdeny-zones;

  # Tests
  tests = {
    orangefs = handleTest ./tests/orangefs.nix;
    banner = handleTest ./tests/banner.nix;
    networkmap = handleTest ./tests/networkmap.nix;
  };
}
