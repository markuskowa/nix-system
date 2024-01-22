{ ... } :

let
  networkingCommon = {
    networking.db = {
      enable = true;
      networks = {
        net1 = {
          prefix = "n";
          subnet = "192.168.10";
          enableEtcHosts = true;
          machList = [
            { node=1; mac="AA:22:33:44:Af:66"; }
            { node=2; mac="AA:22:33:44:Af:67"; name="n-node2"; }
            { node=3; }
          ];
        };
        net2 = {
          prefix = "d";
          subnet = "192.168.11";
          enableEtcHosts = true;
          machList = [
            { node=1; mac="AA:22:33:44:Af:68"; }
            { node=2; mac="AA:22:33:44:Af:69"; name="d-node2"; }
            { node=3; }
          ];
        };
      };
    };
  };

  node = { lib, ... } : {
    virtualisation.vlans = [ 1 2 ];
    imports = [ ../modules/overlay.nix networkingCommon ];
    networking.interfaces = {
      eth1 = {
        ipv4.addresses = lib.mkOverride 0 [ ];
        useDHCP = true;
      };
      eth2 = {
        ipv4.addresses = lib.mkOverride 0 [ ];
        useDHCP = true;
      };
    };
  };

in {
  name = "networkmap";

  nodes = {
    server = { config, lib, ... } :
    with lib;
    let
      hosts = config.networking.db.hosts;

    in {
      virtualisation.vlans = [ 1 2 ];

      services.kea.dhcp4 = {
        enable = true;
        settings = {
          interfaces-config.interfaces = [ "eth1" "eth2" ];
          subnet4 = with config.networking.db.networks; [
            { subnet = "${net1.subnet}.0/24"; reservations-global = true; }
            { subnet = "${net2.subnet}.0/24"; reservations-global = true; }
          ];
        };
      };

      imports = [ ../modules/overlay.nix networkingCommon ];

      networking.db.networks.net1.enableDhcpd = true;
      networking.db.networks.net2.enableDhcpd = true;
      networking.firewall.enable = false;

      networking.interfaces = {
        eth1.ipv4.addresses = mkOverride 0 [ { address = hosts.n3; prefixLength = 24; } ];
        eth2.ipv4.addresses = mkOverride 0 [ { address = hosts.d3; prefixLength = 24; } ];
      };

      environment.etc.test_ip = {
        text = hosts.n1;
      };
    };

    node1 = { pkgs, ... } : {
      imports = [ node ];
      boot.postBootCommands = ''
        ${pkgs.nettools}/bin/ifconfig eth1 hw ether AA:22:33:44:Af:66
        ${pkgs.nettools}/bin/ifconfig eth2 hw ether AA:22:33:44:Af:68
      '';
    };

    node2 = { pkgs, ... } : {
      imports = [ node ];
      boot.postBootCommands = ''
        ${pkgs.nettools}/bin/ifconfig eth1 hw ether AA:22:33:44:Af:67
        ${pkgs.nettools}/bin/ifconfig eth2 hw ether AA:22:33:44:Af:69
      '';
    };
  };

  testScript = ''
    server.wait_for_unit("kea-dhcp4-server.service")
    # Check MAC addresses
    node1.succeed("ifconfig eth1 | grep aa:22:33:44:af:66")
    node1.succeed("ifconfig eth2 | grep aa:22:33:44:af:68")

    node2.succeed("ifconfig eth1 | grep aa:22:33:44:af:67")
    node2.succeed("ifconfig eth2 | grep aa:22:33:44:af:69")

    node1.wait_until_succeeds("ifconfig eth1 | grep 192.168.10.1")
    node1.wait_until_succeeds("ifconfig eth2 | grep 192.168.11.1")

    node2.wait_until_succeeds("ifconfig eth1 | grep 192.168.10.2")
    node2.wait_until_succeeds("ifconfig eth2 | grep 192.168.11.2")

    node1.wait_until_succeeds("ping -c 1 n-node2")
    node1.wait_until_succeeds("ping -c 1 d-node2")

    node1.wait_until_succeeds("ping -c 1 n1")
    node1.wait_until_succeeds("ping -c 1 d1")
  '';
}
