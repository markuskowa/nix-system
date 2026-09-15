{ pkgs, lib, ... } :

let
  genCerts = pkgs.writeShellScript "gen-certs.sh" ''
    set -euo pipefail

    CERT_DIR="/tmp/shared"
    DAYS_VALID=365

    mkdir -p "$CERT_DIR"

    # 1. Generate Root CA Private Key & Self-Signed Certificate
    openssl req -x509 \
      -newkey rsa:2048 \
      -nodes \
      -keyout "$CERT_DIR/ca.key" \
      -out "$CERT_DIR/ca.pem" \
      -days 3650 \
      -subj "/CN=Test Local Root CA"

    # 2. Generate Server Private Key & Certificate Signing Request (CSR)
    openssl req \
      -newkey rsa:2048 \
      -nodes \
      -keyout "$CERT_DIR/server.key" \
      -out "$CERT_DIR/server.csr" \
      -subj "/CN=apd"

    # 3. Create OpenSSL extension config for X.509 v3 extensions (Server Auth)
    cat <<EOF > "$CERT_DIR/server_ext.cnf"
    basicConstraints = CA:FALSE
    keyUsage = digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = DNS:apd, IP:127.0.0.1
    EOF

    # 4. Sign the Server Certificate with the Root CA
    openssl x509 -req \
      -in "$CERT_DIR/server.csr" \
      -CA "$CERT_DIR/ca.pem" \
      -CAkey "$CERT_DIR/ca.key" \
      -CAcreateserial \
      -out "$CERT_DIR/server.pem" \
      -days "$DAYS_VALID" \
      -extfile "$CERT_DIR/server_ext.cnf"

    # Clean up CSR and temp configs
    rm -f "$CERT_DIR/server.csr" "$CERT_DIR/server_ext.cnf" "$CERT_DIR/ca.srl"

    # Set strict permissions on private keys
    chmod 600 "$CERT_DIR/ca.key" "$CERT_DIR/server.key"

    echo "Certificates created in $CERT_DIR}:"
    echo "  CA Certificate:     $CERT_DIR/ca.pem"
    echo "  Server Certificate: $CERT_DIR/server.pem"
    echo "  Server Private Key: $CERT_DIR/server.key"
  '';

  certService = {
    path = [ pkgs.openssl ];
    after = [ "remote-fs.target" ];
    before = [ "hostapd-eth2.service" "hostapd-eth2.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = genCerts;
      Type = "oneshot";
    };
  };

  client = num: { pkgs, ... }: let
        iface = "eth2";
    in {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 (num+1) ];

      networking.interfaces = {
        eth2.ipv4.addresses = lib.mkVMOverride [ { address="192.168.2.${toString num}"; prefixLength=24;} ];
      };

      systemd.tmpfiles.rules = [ "d /run/wpa_supplicant/client 1770 root root -" ];
      systemd.services.wpa = let
        wpaConf = pkgs.writeText "wpa.conf" ''
          ctrl_interface=/run/wpa_supplicant/client
          ap_scan=0
          eapol_version=2
          network={
            key_mgmt=IEEE8021X
            eap=MD5
            identity="user"
	          password="user_password"
          }
        '';

      in {
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


in {
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

          * PEAP,TLS,TTLS
          "macsec"  MSCHAPV2 "user_password" [2]
        '');
        ca_cert = "/tmp/shared/ca.pem";
        server_cert = "/tmp/shared/server.pem";
        private_key = "/tmp/shared/server.key";
      };

      networking.firewall.allowedUDPPorts = [
        config.services.hostapd-radius.auth_port
        config.services.hostapd-radius.acct_port
      ];

      systemd.services.gen-certs = certService;
    };

    apd = { pkgs, lib, ... }: {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 2 3 4 ];

      networking.bridges.ap.interfaces = [ ];
      networking.interfaces = {
        ap.ipv4.addresses = [ { address="192.168.2.254"; prefixLength=24;} ];
        eth2.ipv4.addresses = lib.mkVMOverride [];
        eth2.ipv6.addresses = lib.mkVMOverride [];
        eth3.ipv4.addresses = lib.mkVMOverride [];
        eth3.ipv6.addresses = lib.mkVMOverride [];
        eth4.ipv4.addresses = lib.mkVMOverride [];
        eth4.ipv6.addresses = lib.mkVMOverride [];
      };

      services.hostapd-wired.enable = true;

      services.hostapd-wired.portGroups.eth = {
        bridge = "ap";
        interfaces = [ "eth2" "eth3" ];
        settings = {
          own_ip_addr="192.168.1.1";

          # RADIUS authentication server
          auth_server_addr = "192.168.1.5";
          auth_server_port = 1812;
          auth_server_shared_secret = "radius_password";

          # RADIUS accounting server
          acct_server_addr = "192.168.1.5";
          acct_server_port = 1813;
          acct_server_shared_secret = "radius_password";
        };
      };
      services.hostapd-wired.portGroups.macsec = {
        bridge = "ap";
        interfaces = [ "eth4" ];
        settings = {
          macsec_policy = true;

          own_ip_addr="192.168.1.1";

          # RADIUS authentication server
          auth_server_addr = "192.168.1.5";
          auth_server_port = 1812;
          auth_server_shared_secret = "radius_password";

          # RADIUS accounting server
          acct_server_addr = "192.168.1.5";
          acct_server_port = 1813;
          acct_server_shared_secret = "radius_password";
        };
      };
    };

    client1 = client 1;
    client2 = client 2;

    client-macsec = { pkgs, ... }: {
      imports = [ ../modules/overlay.nix ];
      virtualisation.vlans = [ 1 4 ];

      networking.interfaces = {
        macsec1.ipv4.addresses = lib.mkVMOverride [ { address="192.168.2.14"; prefixLength=24;} ];
      };

      systemd.tmpfiles.rules = [ "d /run/wpa_supplicant/client 1770 root root -" ];
      systemd.services.wpa = let
        wpaConf = pkgs.writeText "wpa.conf" ''
          ctrl_interface=/run/wpa_supplicant/client
          ap_scan=0
          eapol_version=3
          network={
            key_mgmt=IEEE8021X
            eap=TTLS
            identity="macsec"
	          password="user_password"
            macsec_policy=1
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
          { ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -i${iface} -Dmacsec_linux -c ${wpaConf}";
            Restart = "always";
            Type = "simple";
          };
      };
    };
  };

  testScript = ''
    radius.wait_for_unit("multi-user.target")
    apd.wait_for_unit("multi-user.target")
    start_all()
    client1.wait_for_unit("multi-user.target")
    client1.wait_for_unit("wpa.service")
    client2.wait_for_unit("wpa.service")

    apd.wait_until_succeeds("${pkgs.hostapd}/bin/hostapd_cli -p /run/hostapd-eth/ -i eth2 all_sta | grep AUTHORIZED")
    client1.wait_until_succeeds("${pkgs.wpa_supplicant}/bin/wpa_cli -p /run/wpa_supplicant/client status | grep 'EAP state=SUCCESS'")
    client1.wait_until_succeeds("ping -c 1 192.168.2.254")
    client1.wait_until_succeeds("ping -c 1 192.168.2.2")

    client1.wait_until_succeeds("${pkgs.wpa_supplicant}/bin/wpa_cli -p /run/wpa_supplicant/client logoff")
    # Wait until unauthorized
    apd.wait_until_succeeds("${pkgs.hostapd}/bin/hostapd_cli -p /run/hostapd-eth/ -i eth2 status | grep 'num_sta...=0'")
    client1.fail("ping -c 1 192.168.2.254")

    client_macsec.succeed("ip a add 192.168.2.14/24 dev macsec0")
    client_macsec.wait_until_succeeds("ping -c 1 192.168.2.254")
  '';

}
