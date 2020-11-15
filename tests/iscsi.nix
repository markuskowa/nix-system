{ pkgs, lib, ... } :

{
  name = "iscsi";

  nodes = {
    client = { pkgs, ... } :
    let
      secrets = pkgs.writeText "iscsid.secrets" ''
        node.session.auth.authmethod = CHAP
        node.session.auth.username = client
        node.session.auth.password = test
      '';
    in  {
      imports = [ ../modules/overlay.nix ];
      services.iscsid = {
        enable = true;
        config = ''
          node.startup = automatic
        '';

        secrets = "${secrets}";
      };
    };

    server = {
      imports = [ ../modules/overlay.nix ];

      boot.initrd.postDeviceCommands = ''
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data /dev/vdb
      '';

      virtualisation.emptyDiskImages = [ 4096 ];

      networking.firewall.allowedTCPPorts = [ 3260 ];

      services.iscsiTarget.enable = true;
    };
  };


  testScript = ''
    with subtest("Create Target"):
        server.start()
        server.wait_for_unit("multi-user.target")

        # Create target
        server.succeed("test -d /etc/target")
        server.succeed("targetcli /backstores/block create vol /dev/vdb")
        server.succeed("targetcli /iscsi create iqn.2004-01.org.nixos.san:server")
        server.succeed(
            "targetcli /iscsi/iqn.2004-01.org.nixos.san:server/tpg1/luns create /backstores/block/vol"
        )
        server.succeed(
            "targetcli /iscsi/iqn.2004-01.org.nixos.san:server/tpg1/acls create iqn.2004-01.org.nixos.san:client"
        )
        server.succeed(
            "targetcli /iscsi/iqn.2004-01.org.nixos.san:server/tpg1/acls/iqn.2004-01.org.nixos.san:client set auth userid=client"
        )
        server.succeed(
            "targetcli /iscsi/iqn.2004-01.org.nixos.san:server/tpg1/acls/iqn.2004-01.org.nixos.san:client set auth password=test"
        )

        server.succeed("targetcli saveconfig")

    with subtest("Restore Target"):
        server.shutdown()
        server.start()
        server.wait_for_unit("multi-user.target")

        server.succeed("test -f /etc/target/saveconfig.json")
        server.succeed("targetcli ls 1>&2")
        server.succeed("targetcli ls | grep 'iqn.2004-01.org.nixos.san:server'")

    with subtest("Setup initiator"):
        client.start()
        client.wait_for_unit("multi-user.target")

        client.succeed("iscsiadm --mode discovery --op update --type sendtargets -p server")
        client.succeed("iscsiadm --mode node -l all")
        client.wait_for_file("/dev/sda")

        client.succeed("mkdir -p /mnt; mount /dev/sda /mnt")
        client.succeed("touch /mnt/hello")

        client.shutdown()
        client.start()
        client.wait_for_file("/dev/sda")
  '';
}
