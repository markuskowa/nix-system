{ pkgs, ... } :

let
  master = { pkgs, ... } : {
    virtualisation.memorySize = 1024;
    imports = [ ../modules/overlay.nix ];
    networking.firewall.allowedTCPPorts = [ 9419 9420 9421 ];

    services.moosefs.master = {
      enable = true;
      exports = [
        "* / rw,alldirs,admin,maproot=0:0"
        "* . rw"
      ];
    };
  };

  chunkserver = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    networking.firewall.allowedTCPPorts = [ 9422 ];
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

    services.moosefs = {
      masterHost = "master";
      chunkserver = {
        enable = true;
        hdds = [ "~/data" ];
      };
    };
  };

  metalogger = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    #networking.firewall.allowedTCPPorts = [ 9423 ];

    services.moosefs = {
      masterHost = "master";
      metalogger.enable = true;
    };
  };

  client = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];

    services.moosefs.client.enable = true;
  };

in {
  name = "moosefs";
  nodes= {
    inherit master;
    inherit metalogger;
    chunkserver1 = chunkserver;
    chunkserver2 = chunkserver;
    client1 = client;
    client2 = client;
  };

  testScript = ''
    # prepare master server
    master.start()
    master.wait_for_unit("multi-user.target")
    master.succeed("mfsmaster-init")
    master.succeed("systemctl restart mfs-master")
    master.wait_for_unit("mfs-master.service")

    metalogger.wait_for_unit("mfs-metalogger.service")

    for chunkserver in [chunkserver1, chunkserver2]:
        chunkserver.wait_for_unit("multi-user.target")
        chunkserver.succeed("chown moosefs:moosefs /data")
        chunkserver.succeed("systemctl restart mfs-chunkserver")
        chunkserver.wait_for_unit("mfs-chunkserver.service")

    for client in [client1, client2]:
        client.wait_for_unit("multi-user.target")
        client.succeed("mkdir /moosefs")
        client.succeed("mount -t moosefs master:/ /moosefs")

    client1.succeed("echo test > /moosefs/file")
    client2.succeed("grep test /moosefs/file")
  '';
}
