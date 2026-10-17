{ lib, ... } :

let
  common = {
    # Turn of test instrumentation interface configuration
    networking.interfaces = lib.mkVMOverride {};
  };

in {
  name = "ifupdown2";

  nodes = {
    router = { pkgs, lib, ... } : {
      imports = [
        ../modules/ifupdown2.nix
        common
      ];

      virtualisation.vlans = [ 1 ];
      networking.useDHCP = lib.mkVMOverride false;

      services.dnsmasq = {
        enable = true;
        settings = {
          domain-needed = true;
          bogus-priv = true;
          interface = "br0";
          bind-interfaces = true;

          # DHCP range and lease time
          dhcp-range = [ "br0,192.168.1.100,192.168.1.200,12h" ];
        };
      };
      networking.firewall.interfaces."br0".allowedUDPPorts = [ 67 ];

      # Test a vlan aware bridge
      services.ifupdown2 = {
        enable = true;
        iface = {
          br0 = {
            address = [ "192.168.1.1/24" ];
            bridge-ports = [ "eth1" ];
            bridge-stp = true;
            bridge-vlan-aware = true;
            bridge-vids = [ 1 2 ];
            bridge-fd = 3;
          };
          vlan-2 = {
            address = [ "192.168.2.1/24" ];
            vlan-id = 2;
            vlan-raw-device = "br0";
          };
        };
      };
    };

    n1 = { ... } : {
      imports = [
        ../modules/ifupdown2.nix
        common
      ];

      virtualisation.vlans = [ 1 ];

      networking.dhcpcd = {
        enable = lib.mkVMOverride true;
        allowInterfaces = [ "eth1" ];
      };

      services.ifupdown2 = {
        enable = true;
        iface = {
          eth1 = { };
          vlan-2 = {
            vlan-id = 2;
            vlan-raw-device = "eth1";
            address = [ "192.168.2.2/24" ];
          };
        };
      };

    };
  };

  testScript = ''
    router.wait_for_unit("ifupdown2.service")
    router.succeed("ifquery -a --check")
    n1.start()
    n1.wait_until_succeeds("ping -c 1 192.168.1.1")
    n1.wait_until_succeeds("ping -c 1 192.168.2.1")
  '';
}
