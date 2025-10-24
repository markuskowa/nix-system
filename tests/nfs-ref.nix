{ pkgs, ... } :
let
  exportsDir =  "/data/ref_exports";
  nfsrefDir =  "/data/ref_nfsref";

in {
  name = "nfs-referrals";

  nodes = {
    server1 = {...} : {
      services.nfs.server = {
        enable = true;
        exports = ''
          /data 192.168.1.0/24(rw,no_root_squash,no_subtree_check,fsid=0)
          ${exportsDir} 192.168.1.0/24(rw,no_root_squash,no_subtree_check,refer=/@server2)
        '';
        createMountPoints = true;
      };

      # the exports referral needs a dummy bind mount
      virtualisation.fileSystems  = {
        "${exportsDir}" = {
          device = "${exportsDir}";
          fsType = "none";
          options = [ "bind" ];
        };
      };

      networking.firewall.enable = false;
    };

    server2 = {...} : {
      services.nfs.server = {
        enable = true;
        exports = ''
          /data 192.168.1.0/24(rw,no_root_squash,no_subtree_check,fsid=0)
        '';
        createMountPoints = true;
      };

      networking.firewall.enable = false;
    };

    client = {pkgs,lib,...} : {

      virtualisation.fileSystems  = {
        "/data" = {
          device = "server1:/";
          fsType = "nfs4";
          options = [ "vers=4.2" ];
        };
      };

      # Not in upstream yet
      environment.etc."request-key.d/dns_resolver.conf".text = ''
        create dns_resolver  * * ${pkgs.keyutils}/bin/key.dns_resolver %k
      '';

      networking.firewall.enable = false;
    };
  };

  testScript = ''
    server2.start();
    server1.wait_for_unit("nfs-server.service");
    server1.succeed(
        "mkdir ${nfsrefDir}",
        "nfsref add ${nfsrefDir} server2 /"
        );

    server2.wait_for_unit("nfs-server.service");
    client.wait_for_unit("data.mount");

    with subtest("Basic NFS functionality"):
      client.succeed("echo hallo > /data/foo");
      server1.succeed("grep hallo /data/foo");

    with subtest("referral via nfsref"):
      client.wait_until_succeeds("touch ${nfsrefDir}/nfsref");
      server2.wait_for_file("/data/nfsref");

    with subtest("referral via exports"):
      client.succeed("touch ${exportsDir}/exports");
      server2.wait_for_file("/data/exports");
  '';
}
