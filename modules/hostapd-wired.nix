{ lib, pkgs, config, utils, ... } :


let
  inherit (lib)
  types
  optionalString
  mkOption
  mkEnableOption
  mkIf;

  cfg = config.services.hostapd-wired;
  ctrlSocketPath = iface: "/run/hostapd-${iface}";

  settingsFormat = pkgs.formats.keyValueCustom {
    trueVal = "1";
    falseVal = "0";
    separator = "=";
  };

  actionScript = {
    bridge,
    macsec,
  }:
  pkgs.writeShellScript "hostapd-action-script" ''
    IFNAME=$1
    EVENT=$2
    MAC=$3

    IP=${lib.getBin pkgs.iproute2}/bin/ip
    JQ=${lib.getBin pkgs.jq}/bin/jq
    EBTABLES=${lib.getBin pkgs.iptables}/bin/ebtables

    echo "$@"
    found_bridge=$($IP -j -d l show | $JQ "[.[] | select(.linkinfo.info_kind==\"bridge\" and .ifname == \"${bridge}\")] | length")
    echo "bridge: $found_bridge"

    # Ensure bridge exists
    if [ $found_bridge == 0 ]; then
      $IP link add ${bridge} type bridge
    fi

    if [ "$EVENT" = "AP-STA-CONNECTED" ]; then
        ${if macsec then ''
          DEV=$($IP -j -d link show | $JQ -r ".[] | select(.link==\"$IFNAME\" and .linkinfo.info_kind==\"macsec\") | .ifname")
        '' else ''
          DEV=$IFNAME
        ''}

        # Allow EAPOL
        $EBTABLES  -A INPUT  -i $DEV -p 0x888e -j ACCEPT
        $EBTABLES  -A OUTPUT -o $DEV -p 0x888e -j ACCEPT

        # Allow MAC on device
        $EBTABLES  -A INPUT  -i $DEV -s $MAC -j ACCEPT
        $EBTABLES  -A OUTPUT -o $DEV -d $MAC -j ACCEPT
        $EBTABLES  -A OUTPUT -o $DEV -d ff:ff:ff:ff:ff:ff -j ACCEPT

        # Allow bridge forward traffic
        $EBTABLES  -A FORWARD -i $DEV -s $MAC -j ACCEPT
        $EBTABLES  -A FORWARD -o $DEV -d $MAC -j ACCEPT
        $EBTABLES  -A FORWARD -o $DEV -d ff:ff:ff:ff:ff:ff -j ACCEPT

        # Drop all other traffic
        $EBTABLES  -A FORWARD -i $DEV -j DROP
        $EBTABLES  -A FORWARD -o $DEV -j DROP
        $EBTABLES  -A INPUT -i $DEV -j DROP
        $EBTABLES  -A OUTPUT -o $DEV -j DROP
        $IP link set "$DEV" master ${bridge}

        echo "CONNECT: $DEV -> ${bridge} via $MAC"
    elif [ "$EVENT" = "AP-STA-DISCONNECTED" ]; then
        ${if macsec then ''
          DEV=$($IP -j -d link show | $JQ -r ".[] | select(.link==\"$IFNAME\" and .linkinfo.info_kind==\"macsec\") | .ifname")
        '' else ''
          DEV=$IFNAME
        ''}

        # Allow EAPOL
        $EBTABLES  -D INPUT  -i $DEV -p 0x888e -j ACCEPT
        $EBTABLES  -D OUTPUT -o $DEV -p 0x888e -j ACCEPT

        # Allow MAC on device
        $EBTABLES  -D INPUT  -i $DEV -s $MAC -j ACCEPT
        $EBTABLES  -D OUTPUT -o $DEV -d $MAC -j ACCEPT
        $EBTABLES  -D OUTPUT -o $DEV -d ff:ff:ff:ff:ff:ff -j ACCEPT

        # Allow bridge forward traffic
        $EBTABLES  -D FORWARD -i $DEV -s $MAC -j ACCEPT
        $EBTABLES  -D FORWARD -o $DEV -d $MAC -j ACCEPT
        $EBTABLES  -D FORWARD -o $DEV -d ff:ff:ff:ff:ff:ff -j ACCEPT

        # Drop all other traffic
        $EBTABLES  -D FORWARD -i $DEV -j DROP
        $EBTABLES  -D FORWARD -o $DEV -j DROP
        $EBTABLES  -D INPUT -i $DEV -j DROP
        $EBTABLES  -D OUTPUT -o $DEV -j DROP
        $IP link set "$DEV" nomaster
        echo "DISCONNECT: $MAC@$DEV"
    fi
  '';

in {
  options.services.hostapd-wired = {
    enable = mkEnableOption "Wired hostapd";

    default = {};
    portGroups = mkOption {
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          bridge = mkOption {
            description = "Network bridge";
            type = types.str;
            default = "hostapd";
          };

          interfaces = mkOption {
            type = with types; listOf str;
          };

          settings = mkOption {
            description = "hostapd.conf settings";
            type = types.submodule {
              freeformType = settingsFormat.type;
              options = {
                ctrl_interface_group = mkOption {
                  type = types.str;
                  default = "root";
                };

                eap_reauth_period = mkOption {
                  type = types.int;
                  default = 3600;
                };

                use_pae_group_addr = mkOption {
                  type = types.bool;
                  default = true;
                };

                macsec_policy = mkOption {
                  type = types.bool;
                  default = false;
                };

                mka_priority = mkOption {
                  type = types.int;
                  default = 128;
                };

                nas_identifier = mkOption {
                  type = types.str;
                  default = "hostapd";
                };
              };
            };


          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    systemd.services = (lib.mapAttrs' (igroup: icfg: lib.nameValuePair "hostapd-${igroup}" (
      let
        settings = {
            ctrl_interface = ctrlSocketPath igroup;
            ieee8021x = true;
            driver = "${if icfg.settings.macsec_policy then "macsec_linux" else "wired"}";
            eapol_version = if icfg.settings.macsec_policy then 3 else 2;
          } // icfg.settings;

        configFile = settingsFormat.generate "hostapd-${igroup}.conf" settings;
        interfaceDevices = map (x: "sys-subsystem-net-devices-${x}.device" ) icfg.interfaces;
      in {
        path = [ pkgs.hostapd ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        after = interfaceDevices;

        serviceConfig = {
          RuntimeDirectory="hostapd";
          ExecStart = "${lib.getBin pkgs.hostapd}/bin/hostapd ${
            lib.concatStringsSep " " (map (x: "-i ${x}") icfg.interfaces)
          } ${
            lib.concatStringsSep " " (lib.genList (_: configFile) (lib.length icfg.interfaces))
          }";
          Restart = "always";
          RestartSec = "1s";
          Type = "simple";
        };
      })) cfg.portGroups) // (lib.concatMapAttrs (igroup: icfg:
        lib.listToAttrs (
            map (iface: {
              name = "hostapd-event-${igroup}-${iface}";
              value = {
                path = [ pkgs.hostapd ];
                requires = [ "hostapd-${igroup}.service" ];
                after = [ "hostapd-${igroup}.service" ];
                bindsTo = [ "hostapd-${igroup}.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  RuntimeDirectory="hostapd";
                  ExecStart = "${lib.getBin pkgs.hostapd}/bin/hostapd_cli -p ${ctrlSocketPath igroup} -i ${iface} -a ${
                    actionScript {
                      inherit (icfg) bridge;
                      macsec = icfg.settings.macsec_policy;
                    }}";
                  Restart = "always";
                  RestartSec = "1s";
                  Type = "simple";
                };
              };
            }) icfg.interfaces
        )
      )  cfg.portGroups);
  };
}
