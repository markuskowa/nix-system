{ ... } :

let
  server = { pkgs, ... } : {
    imports = [ ../modules/overlay.nix ];
    networking.firewall.allowedTCPPorts = [ 3334 ];
    boot.initrd.postDeviceCommands = ''
      ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data /dev/vdb
    '';

    virtualisation.emptyDiskImages = [ 4096 ];

    fileSystems = pkgs.lib.mkVMOverride
      [ { mountPoint = "/data";
          device = "/dev/disk/by-label/data";
          fsType = "ext4";
        }
      ];

    services.orangefs.server = {
      enable = true;
      dataStorageSpace = "/data/storage";
      metadataStorageSpace = "/data/meta";
      servers = {
        server1 = "tcp://server1:3334";
        server2 = "tcp://server2:3334";
      };
    };
  };

  client = { lib, ... } : {
    imports = [ ../modules/overlay.nix ];
    networking.firewall.enable = true;

    services.orangefs.client = {
      enable = true;
      fileSystems = [{
        target = "tcp://server1:3334/orangefs";
        mountPoint = "/orangefs";
      }];
    };
  };

in {
  name = "orangefs";

  nodes = {
    server1 = server;
    server2 = server;

    client1 = client;
    client2 = client;
  };

  testScript = ''
    # format storage
    foreach my $server  (($server1,$server2))
    {
      $server->start();
      $server->waitForUnit("multi-user.target");
      $server->succeed("mkdir -p /data/storage /data/meta");
      $server->succeed("chown orangefs:orangefs /data/storage /data/meta");
      $server->succeed("chmod 0770 /data/storage /data/meta");
      $server->succeed("sudo -g orangefs -u orangefs pvfs2-server -f /etc/orangefs/server.conf");
    }

    # start services after storage is formated on all machines
    foreach my $server  (($server1,$server2))
    {
      $server->succeed("systemctl start orangefs-server.service");
    }

    # Check if clients can reach and mount the FS
    foreach my $client  (($client1,$client2))
    {
      $client->start();
      $client->waitForUnit("orangefs-client.service");
      # Both servers need to be reachable
      $client->succeed("pvfs2-check-server -h server1 -f orangefs -n tcp -p 3334");
      $client->succeed("pvfs2-check-server -h server2 -f orangefs -n tcp -p 3334");
      $client->waitForUnit("orangefs.mount");

    }

    # R/W test between clients
    $client1->succeed("echo test > /orangefs/file1");
    $client2->succeed("grep test /orangefs/file1");

  '';
}
