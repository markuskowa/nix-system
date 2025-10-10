{ ... } :

let
  server = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    networking.firewall.allowedTCPPorts = [ 2049 ];
    boot.initrd.postDeviceCommands = ''
      ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data /dev/vdb
      ${pkgs.xfsprogs}/bin/mkfs.xfs -L data_xfs /dev/vdc
      ${pkgs.btrfs-progs}/bin/mkfs.btrfs -L data_btrfs /dev/vdd
    '';

    virtualisation.emptyDiskImages = [ 1024 1024 1024 ];

    fileSystems = pkgs.lib.mkVMOverride {
      "/data_vfs" = {
        device = "/dev/disk/by-label/data";
        fsType = "ext4";
      };
      "/data_xfs" = {
        device = "/dev/disk/by-label/data_xfs";
        fsType = "xfs";
      };
      "/data_btrfs" = {
        device = "/dev/disk/by-label/data_btrfs";
        fsType = "btrfs";
      };
    };

    services.nfs-ganesha = {
      enable = true;
      settings = {
        #
        # Minimal working config
        #
        NFSV4 = {
          # Reduce start-up period for test
          Grace_Period = 3;
          Lease_Lifetime = 3;

          # Limit to nfs4.1; nfs4.2 is broken (returns only empty files!).
          Minor_Versions = "0, 1, 2";
        };
      };
      exports = [
        {
          Export_Id = 1;
          Path = "/data_vfs";
          Pseudo = "/vfs";
          Squash = "None";

          Protocols = "4";

          Access_Type = "RW";

          FSAL = {
            Name = "VFS";
          };
        }
        {
          Export_Id = 2;
          Path = "/data_xfs";
          Pseudo = "/xfs";
          Squash = "None";

          Protocols = "4";

          Access_Type = "RW";

          FSAL = {
            Name = "XFS";
          };
        }
        {
          Export_Id = 3;
          Path = "/data_btrfs";
          Pseudo = "/btrfs";
          Squash = "None";

          Protocols = "4";

          Access_Type = "RW";

          FSAL = {
            Name = "VFS";
          };
        }
      ];
    };
  };

  client = { lib, pkgs, ... } : {
    networking.firewall.enable = true;

    fileSystems = lib.mkVMOverride {
      "/data" = {
        device = "server:/";
        fsType = "nfs4";
      };
    };
  };

in {
  name = "nfs-ganesha";

  nodes = {
    server = server;

    client1 = client;
    client2 = client;
  };

  testScript = ''
    server.wait_for_unit("ganesha-nfsd.service")

    # Check if clients can reach and mount the FS
    for client in [client1, client2]:
        client.start()

    for client in [client1, client2]:
      client.wait_for_unit("data.mount")

    # R/W test between clients
    for fs in ["vfs", "xfs", "btrfs"]:
      client1.succeed(f"echo test > /data/{fs}/file1")
      client1.wait_until_succeeds(f"grep test /data/{fs}/file1")
      client2.wait_until_succeeds(f"grep test /data/{fs}/file1")
  '';
}
