{lib, pkgs, ... } :

let
  fixedMac = "52:54:00:12:10:10";

in {
  name = "Kea simple test";

  nodes = {
    server = {
      imports = [ ../modules/kea.nix ];

      services.kea-simple = {
        enable = true;

        interfaces = [ "eth1" ];

        subnets.net1 = {
          subnet = "192.168.1.0/24";
          id = 1;
          pools = [ "192.168.1.10 - 192.168.1.10" ];

          reservations = [{
            hw-address = fixedMac;
            ip-address = "192.168.1.12";
            hostname = "client-new";
          }];
        };
      };
    };

    client = {
      networking.interfaces.eth1 = {
        useDHCP = lib.mkVMOverride true;
        ipv4.addresses = lib.mkVMOverride [];
      };
    };
  };

  testScript = ''
    server.wait_for_unit("kea-dhcp4-server.service")

    client.wait_for_unit("multi-user.target")
    client.succeed('ip a show eth1 | grep "192.168.1.10"')

    client.succeed("systemctl stop dhcpcd")
    client.succeed("ip l set eth1 address ${fixedMac}")
    client.succeed("systemctl start dhcpcd")
    client.wait_for_unit("dhcpcd.service")

    client.wait_until_succeeds('ip a show eth1 | grep "192.168.1.12"')
  '';
}
