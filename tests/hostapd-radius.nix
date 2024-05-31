{ pkgs, ... } :

{
  name = "hostapd-radius";

  nodes = {
    radius = { pkgs, config, ... }: {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 ];

      services.hostapd-radius = {
        enable = true;

        clients_file = toString (pkgs.writeText "client_file" ''
          192.168.1.0/24 radius_password
        '');

        eap_user_file = toString (pkgs.writeText "user_file" ''
          "user"		MD5	"user_password"
        '');
      };

      networking.firewall.allowedUDPPorts = [
        config.services.hostapd-radius.auth_port
        config.services.hostapd-radius.acct_port
      ];
    };

    apd = { pkgs, lib, ... }: {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 2 ];

      services.hostapd-wired = {
        enable = true;
        interface = "eth2";

        extraConfig = ''
          ieee8021x=1
          eap_reauth_period=3600
          use_pae_group_addr=1


          own_ip_addr=192.168.1.1

          nas_identifier=apd

          # RADIUS authentication server
          auth_server_addr=192.168.1.3
          auth_server_port=1812
          auth_server_shared_secret=radius_password

          # RADIUS accounting server
          acct_server_addr=192.168.1.3
          acct_server_port=1813
          acct_server_shared_secret=radius_password
        '';
      };
    };

    client = { pkgs, ... }: {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 2 ];

      systemd.services.wpa = let
        wpaConf = pkgs.writeText "wpa.conf" ''
          ctrl_interface=/run/wpa_supplicant
          ap_scan=0
          eapol_version=2
          network={
            key_mgmt=IEEE8021X
            eap=MD5
            identity="user"
	          password="user_password"
          }
        '';

        iface = "eth2";
      in {
        path = [   pkgs.hostapd ];
        after = [ "sys-subsystem-net-devices-${iface}.device" ];
        bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];
        requiredBy = [ "network-link-${iface}.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig =
          { ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -i${iface} -Dwired -c ${wpaConf}";
            Restart = "always";
            Type = "simple";
          };
      };
    };
  };

  testScript = ''
    radius.wait_for_unit("multi-user.target")
    apd.wait_for_unit("multi-user.target")
    client.wait_for_unit("multi-user.target")
    client.wait_for_unit("wpa.service")

    apd.wait_until_succeeds("${pkgs.hostapd}/bin/hostapd_cli all_sta  | grep AUTHORIZED")
    client.wait_until_succeeds("${pkgs.wpa_supplicant}/bin/wpa_cli status | grep 'EAP state=SUCCESS'")
  '';

}
