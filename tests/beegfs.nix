{ ... } :

let

  common = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    boot.initrd.postDeviceCommands = ''
      ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data /dev/vdb
    '';

    virtualisation.emptyDiskImages = [ 4096 ];

    fileSystems = pkgs.lib.mkVMOverride {
      "/data" = {
        device = "/dev/disk/by-label/data";
        fsType = "ext4";
      };
    };
  };

  mgmtd = { pkgs, ... } : {
    imports = [ common ];

    networking.firewall.allowedTCPPorts = [ 8008 ];
    networking.firewall.allowedUDPPorts = [ 8008 ];

    services.beegfs2.mgmtd = {
      enable = true;
      settings = {
        storeMgmtdDirectory = "/data";
        storeAllowFirstRunInit = true;
        sysAllowNewServers = true;
        sysAllowNewTargets = true;
      };
    };
  };

  meta = { pkgs, ... } : {
    imports = [ common ];

    networking.firewall.allowedTCPPorts = [ 8005 ];
    networking.firewall.allowedUDPPorts = [ 8005 ];

    services.beegfs2.mgmtdHost = "mgmtd";
    services.beegfs2.meta = {
      enable = true;
      settings = {
        sysMgmtdHost = "mgmtd";
        storeMetaDirectory = "/data";
        storeAllowFirstRunInit = true;
      };
    };
  };

  storage = { pkgs, ... } : {
    imports = [ common ];

    networking.firewall.allowedTCPPorts = [ 8003 ];
    networking.firewall.allowedUDPPorts = [ 8003 ];

    services.beegfs2.mgmtdHost = "mgmtd";
    services.beegfs2.storage= {
      enable = true;
      settings = {
        storeStorageDirectory = "/data";
        storeAllowFirstRunInit = true;
      };
    };
  };

  client = { lib, pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];

    networking.firewall.enable = true;

    services.beegfs2.mgmtdHost = "mgmtd";
    services.beegfs2.client = {
      enable = true;
      mountPoint = "/data";
    };
  };

in {
  name = "beegfs";

  nodes = {
    inherit mgmtd meta storage;

    client1 = client;
    client2 = client;
  };

  testScript = ''
    mgmtd.wait_for_unit("beegfs-mgmtd.service")
    meta.wait_for_unit("beegfs-meta.service")
    storage.wait_for_unit("beegfs-storage.service")

    # Check if clients can reach and mount the FS
    for client in [client1, client2]:
      client.wait_for_unit("multi-user.target")

    # R/W test between clients
    client1.wait_for_unit("data.mount")
    client1.succeed("echo test > /data/file1")

    client2.wait_for_unit("data.mount")
    client2.succeed("grep test /data/file1")
  '';
}
