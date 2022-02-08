{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
} :

let
  handleTest = t: (import "${nixpkgs}/nixos/tests/make-test-python.nix") (import t);
  pkgs = (import nixpkgs) { overlays = [ (import ./default.nix) ]; };

  #nixosTests = import "${nixpkgs}/nixos/tests/all-tests.nix" {
  #  inherit pkgs system;
  #  callTest = t: pkgs.lib.hydraJob t.test;
  #};

in rec {
  # Evaluate overlay packages
  inherit (pkgs)
    nfs-ganesha
    nhc
    target-isns
    ipdeny-zones
    slurm
    redfishtool;

  # Tests
  tests = {
    infiniband = handleTest ./tests/infiniband.nix {};
    nfs-ganesha = handleTest ./tests/nfs-ganesha.nix {};
    banner = handleTest ./tests/banner.nix {};
    iscsi = handleTest ./tests/iscsi.nix {};
    iscsiBoot = handleTest ./tests/iscsiBoot.nix {};
    isns = handleTest ./tests/isns.nix {};
    networkmap = handleTest ./tests/networkmap.nix {};
    geoblocking = handleTest ./tests/geoblocking.nix {};
    sshCA = handleTest ./tests/sshCA.nix {};
    zfsAttrs = handleTest ./tests/zfs-attr.nix {};
    userInit = handleTest ./tests/userInit.nix;
  };

  upstreamTests = {
    inherit (pkgs.nixosTests)
      borgbackup
      influxdb
      grafana
      moosefs
      redmine
      slurm
      telegraf;
  };

  tested = pkgs.releaseTools.aggregate {
    name = "tests";
    constituents = [
      "tests.nfs-ganesha"
      "tests.moosefs"
      "tests.banner"
      "tests.sshCA"
      "tests.networkmap"
      "tests.zfsAttrs"
      # essential upstream tests
      "upstreamTests.borgbackup"
      "upstreamTests.influxdb"
      "upstreamTests.grafana"
      "upstreamTests.moosefs"
      "upstreamTests.redmine.mysql"
      "upstreamTests.redmine.pgsql"
      "upstreamTests.slurm"
      "upstreamTests.telegraf"
    ];
  };
}
