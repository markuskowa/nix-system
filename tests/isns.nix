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
      imports = [ ../modules/iscsid.nix ];
      nixpkgs.overlays = [ (import ../default.nix) ];

      # iscsid picks the IPv6 address of server
      # and tries it first (which fails).
      networking.enableIPv6 = false;

      services.iscsid = {
        enable = true;
        scanTargets = [ { target="ns"; type="isns"; } ];

        secrets = "${secrets}";
      };
    };

  server = {
    imports = [ ../modules/iscsiTarget.nix ];
    nixpkgs.overlays = [ (import ../default.nix) ];

    virtualisation.emptyDiskImages = [ 4096 ];

    networking.enableIPv6 = false;
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
    targetcli /iscsi/${iqn "server" n}/tpg1 set attribute authentication=1
    targetcli /iscsi/${iqn "server" n}/tpg1/acls/${iqn "client" n} set auth userid=client${toString n}
    targetcli /iscsi/${iqn "server" n}/tpg1/acls/${iqn "client" n} set auth password=test
    targetcli /iscsi/${iqn "server" n}/tpg1/portals delete ::0 3260
    targetcli /iscsi/${iqn "server" n}/tpg1/portals create 0.0.0.0 3260

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
      imports = [ ../modules/isns.nix ];
      nixpkgs.overlays = [ (import ../default.nix) ];

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
    ns.wait_for_unit("multi-user.target")

    # Check creation of discovery domains
    ns.succeed("isnsadm --local --list dds | grep domain1")
    ns.succeed("isnsadm --local --list dds | grep domain2")

    for server in [server1, server2]:
        server.wait_for_unit("multi-user.target")
        server.succeed("test -d /etc/target")

    # Create target
    # Needed to restart target-isns
    server1.succeed("${targetInit 1}")
    server1.start_job("target-isns.service")
    server2.succeed("${targetInit 2}")
    server2.start_job("target-isns.service")


    # Check registration of nodes
    for server in [ "server1", "server2" ]:
        ns.succeed(f"isnsadm --local --list nodes | grep {server}")


    for client in [client1, client2]:
        client.start()
        client.wait_for_unit("multi-user.target")
        client.wait_for_unit("iscsi.service")

        client.wait_for_file("/dev/sda")
  '';
}
