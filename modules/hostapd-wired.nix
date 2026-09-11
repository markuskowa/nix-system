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

        $EBTABLES -t nat -A PREROUTING -i $DEV -j DROP
        $EBTABLES -t nat -A POSTROUTING -o $DEV -j DROP
        $EBTABLES -t nat -I PREROUTING 1 -s $MAC -j ACCEPT
        $EBTABLES -t nat -I POSTROUTING 1 -d $MAC -j ACCEPT
        $IP link set "$DEV" master ${bridge}

        echo "CONNECT: $DEV -> ${bridge} via $MAC"
    elif [ "$EVENT" = "AP-STA-DISCONNECTED" ]; then
        ${if macsec then ''
          DEV=$($IP -j -d link show | $JQ -r ".[] | select(.link==\"$IFNAME\" and .linkinfo.info_kind==\"macsec\") | .ifname")
        '' else ''
          DEV=$IFNAME
        ''}

        $EBTABLES -t nat -D PREROUTING -s $MAC -j ACCEPT
        $EBTABLES -t nat -D POSTROUTING -d $MAC -j ACCEPT
        $IP link set "$DEV" nomaster
        echo "DISCONNECT: $MAC@$DEV"
    fi
  '';

in {
  options.services.hostapd-wired = {
    enable = mkEnableOption "Wired hostapd";

    default = {};
    interfaces = mkOption {
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          bridge = mkOption {
            description = "Network bridge";
            type = types.str;
            default = "hostapd";
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
              };
            };


          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d /run/hostapd 1770 root root -" ];
    systemd.services = (lib.mapAttrs' (iface: icfg: lib.nameValuePair "hostapd-${iface}" (
      let
        settings = {
            ctrl_interface = ctrlSocketPath iface;
            ieee8021x = true;
            interface = iface;
            driver = "${if icfg.settings.macsec_policy then "macsec_linux" else "wired"}";
            eapol_version = if icfg.settings.macsec_policy then 3 else 2;
          } // icfg.settings;

        configFile = settingsFormat.generate "hostapd-${iface}.conf" settings;
      in {
        path = [ pkgs.hostapd ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        after = [ "sys-subsystem-net-devices-${iface}.device" ];
        bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];

        serviceConfig = {
          RuntimeDirectory="hostapd";
          ExecStart = "${lib.getBin pkgs.hostapd}/bin/hostapd ${configFile}";
          Restart = "always";
          RestartSec = "1s";
          Type = "simple";
        };
      })) cfg.interfaces) //
      (lib.mapAttrs' (iface: icfg: lib.nameValuePair "hostapd-event-${iface}" (
      {
        path = [ pkgs.hostapd ];
        requires = [ "hostapd-event-${iface}.service" ];
        after = [ "hostapd-event-${iface}.service" ];
        bindsTo = [ "hostapd-event-${iface}.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          RuntimeDirectory="hostapd";
          ExecStart = "${lib.getBin pkgs.hostapd}/bin/hostapd_cli -p ${ctrlSocketPath iface} -i ${iface} -a ${
            actionScript {
              inherit (icfg) bridge;
              macsec = icfg.settings.macsec_policy;
            }}";
          Restart = "always";
          RestartSec = "1s";
          Type = "simple";
        };
      })) cfg.interfaces);
  };
}
