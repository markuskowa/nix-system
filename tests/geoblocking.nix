{ ... } :

{
  name = "geoblocking";

  nodes = {
    server = { config, lib, ... } :  {
      virtualisation.vlans = [ 1 ];
      imports = [ ../modules/overlay.nix ];
      networking.interfaces = {
        eth1.ipv4.addresses = lib.mkOverride 0 [ { address = "10.10.0.2"; prefixLength = 24; } ];
      };

      networking.defaultGateway = {
        address = "10.10.0.1";
        interface = "eth1";
      };

      networking.firewall = {
        enable = false;
        countries = [ "us" ];
        countryWhitelist = true;
      };
    };

    router =  { config, lib, ... } :  {
      virtualisation.vlans = [ 1 2 3 ];
      imports = [ ../modules/overlay.nix ];
      networking.interfaces = {
        eth1.ipv4.addresses = lib.mkOverride 0 [ { address = "10.10.0.1"; prefixLength = 24; } ];

        # This is in the US zone
        eth2.ipv4.addresses = lib.mkOverride 0 [ { address = "4.0.0.1"; prefixLength = 24; } ];

        # This is in the SY zone
        eth3.ipv4.addresses = lib.mkOverride 0 [ { address = "5.0.0.1"; prefixLength = 24; } ];
      };

      networking.firewall = {
        enable = false;
      };

      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv4.conf.default.forwarding" = true;
      };
    };

    client1 = { config, lib, ... } :  {
      virtualisation.vlans = [ 3 ];
      imports = [ ../modules/overlay.nix ];
      networking.interfaces = {
        eth3.ipv4.addresses = lib.mkOverride 0 [ { address = "5.0.0.2"; prefixLength = 24; } ];
      };

      networking.defaultGateway = {
        address = "5.0.0.1";
        interface = "eth3";
      };

      networking.firewall.enable = false;
    };

    client2 = { config, lib, ... } :  {
      virtualisation.vlans = [ 2 ];
      imports = [ ../modules/overlay.nix ];
      networking.interfaces = {
        eth2.ipv4.addresses = lib.mkOverride 0 [ { address = "4.0.0.2"; prefixLength = 24; } ];
      };

      networking.defaultGateway = {
        address = "4.0.0.1";
        interface = "eth2";
      };

      networking.firewall.enable = false;
    };
  };

  testScript = ''
    router.start()
    server.wait_for_unit("network.target")

    client1.wait_for_unit("network.target")
    client1.succeed("ip a 1>&2")
    client1.succeed("ip r 1>&2")
    client1.succeed("ping -c 1 server")

    client2.wait_for_unit("network.target")
    client2.succeed("ping -c 1 server")
  '';
}
