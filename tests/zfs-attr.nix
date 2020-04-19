{ ... } :

{
  name = "ZFSDeclarativeProperties";

  nodes = {
    machine = { pkgs, ... } : {
      virtualisation.emptyDiskImages = [ 4096 ];

      imports = [ ../modules/overlay.nix ];
      boot.supportedFilesystems = [ "zfs" ];

      boot.zfs.devNodes = "/dev/disk/by-uuid/";
      networking.hostId = "00000000";

      boot.zfs.extraPools = [ "rpool" ];

      services.zfs.datasets = {
        enable = true;
        properties."rpool/vol".quota = "1G";
      };
    };
  };

  testScript = ''
    $machine->succeed("zpool create rpool /dev/vdb");

    $machine->shutdown();

    $machine->waitForUnit("multi-user.target");

    $machine->succeed("zfs get quota rpool/vol | grep 1G");
  '';
}
