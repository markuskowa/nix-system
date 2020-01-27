{ nixpkgs ? (import <nixpkgs>) { overlays = [ (import ./default.nix) ]; } } :

let
  handleTest = t: (import <nixpkgs/nixos/tests/make-test.nix>) (import t);

in {
  # Evaluate overlay packages
  inherit (nixpkgs)
    nfs-ganesha
    orangefs
    ipdeny-zones
    redfishtool;

  # Tests
  tests = nixpkgs.recurseIntoAttrs {
    infiniband = handleTest ./tests/infiniband.nix {};
    nfs-ganesha = handleTest ./tests/nfs-ganesha.nix {};
    orangefs = handleTest ./tests/orangefs.nix {};
    banner = handleTest ./tests/banner.nix {};
    networkmap = handleTest ./tests/networkmap.nix {};
    sshCA = handleTest ./tests/sshCA.nix {};
    zfsAttrs = handleTest ./tests/zfs-attr.nix {};
  };
}
