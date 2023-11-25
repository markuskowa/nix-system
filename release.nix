{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
} :

let
  handleTest = t: (import "${nixpkgs}/nixos/tests/make-test-python.nix") (import t);
  pkgs = (import nixpkgs) {
    overlays = [ (import ./default.nix) ];
    config.allowUnfree = true;
  };

  #nixosTests = import "${nixpkgs}/nixos/tests/all-tests.nix" {
  #  inherit pkgs system;
  #  callTest = t: pkgs.lib.hydraJob t.test;
  #};

in rec {
  # Evaluate overlay packages
  inherit (pkgs)
    beegfs
    enroot
    nhc
    target-isns
    ipdeny-zones
    slurm-spank-stunnel
    slurm-spank-pyxis
    redfishtool;

    # beegfs-client = pkgs.linuxPackages.beegfs;

  # Tests
  tests = {
    # beegfs = handleTest ./tests/beegfs.nix {};
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
    vxlan = handleTest ./tests/vxlan.nix;
    # slurm = handleTest ./tests/slurm.nix {};
  };

  upstreamTests = {
    inherit (pkgs.nixosTests)
      borgbackup
      influxdb
      moosefs
      redmine
      slurm
      telegraf;
      grafana = pkgs.nixosTests.grafana.basic;
  };

  tested = pkgs.releaseTools.aggregate {
    name = "tests";
    constituents = [
      "tests.nfs-ganesha"
      "tests.banner"
      "tests.sshCA"
      # "tests.networkmap"
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
