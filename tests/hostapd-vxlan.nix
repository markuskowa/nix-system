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

  client = num: { pkgs, config, ... }: let
        iface = "vx1";
    in {
      imports = [ ../modules/overlay.nix ];

      networking.interfaces = {
        macsec0.ipv4.addresses = lib.mkVMOverride [ { address="192.168.2.${toString num}"; prefixLength=24;} ];
      # vx1-macsec1.ipv4.addresses = lib.mkOverride 0 [ { address = "10.11.0.${toString i}"; prefixLength = 24; }];
      };

      networking.vxlans.vx1 = {
        vni = 100 + num;
        dev = "eth1";
      };

      networking.firewall.enable = false;
      networking.firewall.allowedUDPPorts = [
        config.networking.vxlans.vx1.port
      ];

      systemd.tmpfiles.rules = [ "d /run/wpa_supplicant/client 1770 root root -" ];
      systemd.services.wpa = let
        wpaConf = pkgs.writeText "wpa.conf" ''
          ctrl_interface=/run/wpa_supplicant/client

          ap_scan=0
          eapol_version=3
          network={
            key_mgmt=IEEE8021X
            eap=TTLS
            eapol_flags=0
            identity="macsec"
	          password="user_password"
            macsec_policy=1
          }
        '';

      in {
        after = [ "sys-subsystem-net-devices-${iface}.device" ];
        bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig =
          { ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -i${iface} -Dmacsec_linux -c ${wpaConf}";
            Restart = "always";
            Type = "simple";
          };
      };
    };


in {
  name = "hostapd-radius";
  sshBackdoor.enable = true;

  nodes = {
    apd = { pkgs, lib, config, ... }: {
      imports = [ ../modules/overlay.nix ];

      networking.vxlans.vx1 = {
        vni = 101;
        dev = "eth1";
      };

      networking.vxlans.vx2 = {
        vni = 102;
        dev = "eth1";
      };

      networking.firewall.enable = false;
      networking.firewall.allowedUDPPorts = [
        config.networking.vxlans.vx1.port
        config.networking.vxlans.vx2.port
      ];

      networking.bridges.ap.interfaces = [ ];
      networking.interfaces = {
        ap.ipv4.addresses = [ { address="192.168.2.254"; prefixLength=24;} ];
        vx1.useDHCP = false;
        # macsec0.ipv4.addresses = lib.mkVMOverride [ { address="192.168.2.${toS"; prefixLength=24;} ];
        macsec0.useDHCP = false;
        macsec1.useDHCP = false;
      };


      systemd.services.gen-certs = certService;

      services.hostapd-wired.enable = true;

      services.hostapd-wired.portGroups.vxlan = {
        bridge = "ap";
        interfaces = [ "vx1" "vx2" ];
        settings = {
          macsec_policy = true;
          logger_stdout = 1;

          eap_server = 1;
          eap_user_file = toString (pkgs.writeText "user_file" ''
            "user"		MD5	"user_password"

            * PEAP,TLS,TTLS
            "macsec"  MSCHAPV2 "user_password" [2]
          '');

          ca_cert = "/tmp/shared/ca.pem";
          server_cert = "/tmp/shared/server.pem";
          private_key = "/tmp/shared/server.key";
        };
      };
    };

    client1 = client 1;
    client2 = client 2;

  };

  testScript = ''
    apd.wait_for_unit("multi-user.target")
    start_all()
    client1.wait_for_unit("multi-user.target")
    client1.wait_for_unit("wpa.service")
    client2.wait_for_unit("wpa.service")

    client1.wait_until_succeeds("ping -c 1 192.168.2.254")
    client1.wait_until_succeeds("ping -c 1 192.168.2.2")
  '';

}
