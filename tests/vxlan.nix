{ ... } :

let
  vs-config = {
    vs0 = {
      interfaces = {
        vs-host.type = "internal";
        vs-container.type = "internal";
      };
    };
  };

  common = {
    imports = [ ../modules/overlay.nix ];

    networking.bridges.ve-br.interfaces = [  "ve-0" "vxlan1" ];

    networking.vxlans.vxlan1 = {
      id = 1;
      dev = "eth1";
    };

    networking.firewall.allowedUDPPorts = [ 4789 ]; # VXLAN default port

    networking.interfaces.ve-0.virtual = true;
    networking.interfaces.eth1.mtu = 1550;


    containers.c1 = {
      autoStart = true;
      hostBridge = "ve-br";
      privateNetwork = true;
      config.networking.firewall.allowedTCPPorts = [ 2000 ]; # Port for nc test
    };
  };

in {
  name = "VXLAN";

  nodes = {
    node1 = {...} : {
      imports = [ common ];

      networking.interfaces.ve-br.ipv4.addresses = [{ address="192.168.2.1"; prefixLength=24;}];

      containers.c1.localAddress = "192.168.2.11/24";
    };

    node2 = {...} : {
      imports = [ common ];

      networking.interfaces.ve-br.ipv4.addresses = [{ address="192.168.2.2"; prefixLength=24;}];

      containers.c1.localAddress = "192.168.2.12/24";
    };
  };

  testScript = ''
    node1.wait_for_unit("network.target")
    node2.wait_for_unit("network.target")

    node1.succeed("ping -c 3 node2")
    node1.succeed("ping -c 3 192.168.2.12")
    node1.succeed("machinectl shell c1 /run/current-system/sw/bin/ping -c 3 192.168.2.12")
  '';
}
