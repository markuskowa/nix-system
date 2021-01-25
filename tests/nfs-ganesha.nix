{ ... } :

let
  server = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    networking.firewall.allowedTCPPorts = [ 2049 ];
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

    services.nfs-ganesha = {
      enable = true;
      settings = {
        #
        # Minimal working config
        #
        NFS_CORE_PARAM = {
          Enable_UDP = false;
        };
        NFS_KRB5 = {
          Active_krb5 = false;
        };
        EXPORT_DEFAULTS = {
          SecType = "sys";
          Protocols = "V4";
        };
        EXPORT = {
          Export_Id = 0;
          Path = "/data";
          Pseudo = "/";
          Squash = "None";

          Protocols = "V4";

          Access_Type = "RW";

          FSAL = {
            Name = "VFS";
          };
        };
      };
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
        client.wait_for_unit("multi-user.target")

    # R/W test between clients
    client1.wait_for_unit("data.mount")
    client2.wait_for_unit("data.mount")

    client1.succeed("echo test > /data/file1")
    client2.succeed("grep test /data/file1")
  '';
}
