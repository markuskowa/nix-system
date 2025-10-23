{ pkgs, ... } :

{
  name = "nfs-ref";

  nodes = {
    server1 = {...} : {
      services.nfs.server = {
        enable = true;
        exports = ''
          /data 192.168.1.0/255.255.255.0(rw,no_root_squash,no_subtree_check,fsid=0)
        '';
        createMountPoints = true;
      };

      networking.firewall.enable = false;
    };

    server2 = {...} : {
      services.nfs.server = {
        enable = true;
        exports = ''
          /data 192.168.1.0/255.255.255.0(rw,no_root_squash,no_subtree_check,fsid=0)
        '';
        createMountPoints = true;
      };

      networking.firewall.enable = false;
    };

    client = {...} : {

      virtualisation.fileSystems  = {
        "/data" = {
          device = "server1:/";
          fsType = "nfs";
          options = [ "vers=4.2" ];
        };
      };

      networking.firewall.enable = false;
    };
  };

  testScript = ''
    server1.wait_for_unit("nfs-server.service");
    server2.wait_for_unit("nfs-server.service");
    server1.succeed("mkdir /data/ref && nfsref add /data/ref server2 /");
    client.wait_for_unit("data.mount");

    client.succeed("echo hallo > /data/foo");
    server1.succeed("grep hallo /data/foo");

    client.succeed("ls -ld /data/ref/");
    client.succeed("echo hallo > /data/ref/foo");
    server2.succeed("grep hallo /data/ref/foo");
  '';
}

