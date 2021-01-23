{ pkgs, lib, ... } :

let
  client = name: { pkgs, ... } :
    let
      secrets = pkgs.writeText "iscsid.secrets" ''
        node.session.auth.authmethod = CHAP
        node.session.auth.username = ${name}
        node.session.auth.password = test
      '';

    in {
      imports = [ ../modules/overlay.nix ];
      services.iscsid = {
        enable = true;
        scanTargets = [ { target="ns"; type="isns"; } ];

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

    services.iscsiTarget = {
      enable = true;
      isns = {
        enable = true;
        server = "ns";
      };
    };
  };

  iqn = name: x: "iqn.2004-01.org.nixos.san:${name}${toString x}";
  targetInit = n: pkgs.writeShellScript "targetInit" ''
    targetcli /backstores/block create vol /dev/vdb
    targetcli /iscsi create ${iqn "server" n}

    targetcli /iscsi/${iqn "server" n}/tpg1/luns create /backstores/block/vol
    targetcli /iscsi/${iqn "server" n}/tpg1/acls create ${iqn "client" n}
    targetcli /iscsi/${iqn "server" n}/tpg1/acls/${iqn "client" n} set auth userid=client${toString n}
    targetcli /iscsi/${iqn "server" n}/tpg1/acls/${iqn "client" n} set auth password=test

    targetcli saveconfig
  '';

in {
  name = "isns";

  nodes = {
    client1 = client "client1";
    client2 = client "client2";

    server1 = server;
    server2 = server;

    ns =  {
      imports = [ ../modules/overlay.nix ];

      services.isnsd = {
        enable = true;
        registerControl = true;
        discoveryDomains = {
          domain1 = [
            "iqn.2004-01.org.nixos.san:server1"
            "iqn.2004-01.org.nixos.san:client1"
          ];
          domain2 = [
            "iqn.2004-01.org.nixos.san:server2"
            "iqn.2004-01.org.nixos.san:client2"
          ];
        };
      };

      networking.firewall.allowedTCPPorts = [ 3205 ];
    };
  };


  testScript = ''
    ns.start()
    ns.wait_for_unit("multi-user.target")

    # Check creation of discovery domains
    ns.succeed("isnsadm --local --list dds | grep domain1")
    ns.succeed("isnsadm --local --list dds | grep domain2")

    for server in [server1, server2]:
        server.start()
        server.wait_for_unit("multi-user.target")
        server.succeed("test -d /etc/target")

    # Create target
    server1.succeed("${targetInit 1}")
    server2.succeed("${targetInit 2}")

    for server in [server1, server2]:
        server.shutdown()
        server.start()
        server.wait_for_unit("multi-user.target")

        server.succeed("test -f /etc/target/saveconfig.json")
        server.succeed("targetcli ls 1>&2")
        server.succeed("targetcli ls | grep 'iqn.2004-01.org.nixos.san:server'")

    # Check registration of nodes
    ns.succeed("isnsadm --local --list nodes | grep server1")
    ns.succeed("isnsadm --local --list nodes | grep server2")


    for client in [client1, client2]:
        client.start()
        client.wait_for_unit("multi-user.target")

        client.wait_for_file("/dev/sda")

        client.succeed("mkdir -p /mnt; mount /dev/sda /mnt")
        client.succeed("touch /mnt/hello")

        client.shutdown()
  '';
}
