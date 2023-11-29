{ lib, ... } :

let
  common = {
    virtualisation.vlans = [ 1 2 ];
  };

  node = i: { pkgs, ... } : {
    imports = [ common ../modules/overlay.nix ];
    environment.systemPackages = [ pkgs.wpa_supplicant ];
    # environment.etc."wpa.conf".source = wpaConf;
    networking.interfaces = {
      eth2.ipv4.addresses = lib.mkOverride 0 [ ];
      eth2-macsec1.ipv4.addresses = lib.mkOverride 0 [ { address = "10.11.0.${toString i}"; prefixLength = 24; }];
    };

    services.wired-supplicant = {
      enable = true;
      interfaces.eth2 = {
        networks = [{
          macsec_policy = true;
          mka_cak = toString (pkgs.writeText "mka_key" "df437b25eeef4328c6aba57e0c6fd84e");
          mka_ckn = "bc27a825688804009d9dee722665f2ca1906edcf64e70173216b12edbcf0b650";
          extraConfig = "mka_priority=${toString i}";
        }];
      };
    };
  };

in {
  name = "MACSEC-PSK";

  nodes = {
    node1 = node 1;
    node2 = node 2;
    node3 = node 3;
  };

  testScript = ''
    start_all()
    for node in machines:
      node.wait_for_unit("network-online.target")

    for node in machines:
      node.wait_until_succeeds("wpa_cli status | grep Secured=Yes")

    for i in [ 2, 3 ]:
      node.succeed("ping -c3 node{}".format(i))
  '';
}
