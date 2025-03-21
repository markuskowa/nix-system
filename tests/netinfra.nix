{ ... }:


let
  network = {
    imports = [
      ../modules/netinfra.nix
      ../modules/kea.nix
    ];
    infra = {
      vlans = {
        vlan-test.id = 2;
      };

      networks = {
        vnet = {
          subnet = "192.168.10.0";
          gateway = 254;
          dns = ["1.1.1.1"];
          hosts = {
            mach1 = { hostIndex = 1; dns="master.vlan"; };
            mach2 = { hostIndex = 2; };
          };
        };
        net1 = {
          subnet = "192.168.9.0";
          gateway = 254;
          dns = ["1.1.1.1"];
          pools = [{ begin = 20; end = 30; }];
          dhcpManaged = true;

          hosts = {
            mach1 = { hostIndex = 1; dns="master.lan"; };
            mach2 = { hostIndex = 2; };
            mach3 = { hostIndex = 3; mac = "00:11:22:AA:BB:CC"; dns="host3.local.com";};
            gw = { hostIndex = 254; };
          };
        };
      };

      hosts = {
        gw = {
          defaultInterface = "eth1";
          interfaces.eth1 = { network = "net1"; };
        };

        mach1 = {
          interfaces= {
            vlan-2 = { network = "vnet"; vlan = { name = "vlan-test"; interface = "eth1"; }; };
            eth1 = { network = "net1"; };
          };
        };
        mach2 = {
          defaultInterface = "vlan-test";
          etcHosts = [ "net1" ];
          interfaces = {
            vlan-test = { network = "vnet"; vlan = { name = "vlan-test"; interface = "eth1"; }; };
            eth1 = { network = "net1"; };
          };
        };
      };

    };

  };

in {
  name = "netinfra";

  nodes = {
    gw = {
      imports = [ network ];
      services.kea-simple = {
        enable = true;
        useInfra = true;
        interfaces = [ "eth1" ];
      };
    };
    mach1 = {
      imports = [ network ];
    };
    mach2 = {
      imports = [ network ];
    };
  };

  testScript = ''
  '';
}
