{ lib, pkgs, config, utils, ... } :

let
  inherit (lib)
  types
  mkOption
  mkEnableOption
  mkIf
  concatStringsSep
  flatten
  filter
  nameValuePair
  listToAttrs
  mapAttrsToList
  mapAttrs';

  cfg = config.services.wired-supplicant;

  # We must escape interfaces due to the systemd interpretation
  subsystemDevice = interface:
    "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device";


  cfgFile = iface: x: pkgs.writeText "wpa_supplicant.conf" ''
    ctrl_interface=/run/wpa_supplicant
    ap_scan=0
    eapol_version=${toString x.eapol_version}
    ${concatStringsSep "\n" (map (net: ''
        network={
          key_mgmt=${net.key_mgmt}
          eapol_flags=${toString net.eapol_flags}
          macsec_policy=${if net.macsec_policy then "1" else "0"}
          macsec_port=${toString net.macsec_port}
          macsec_replay_protect=${toString net.macsec_replay_protect}
          macsec_replay_window=${toString net.macsec_replay_window}
          mka_cak=${net.mka_cak}
          mka_ckn=${net.mka_ckn}
          ${net.extraConfig}
        }
    '') x.networks)}
  '';


in {
  options.services.wired-supplicant = {
    enable = mkEnableOption "Wired WAP supplicant";

    package = mkOption {
      type = types.package;
      default = pkgs.wpa_supplicant;
    };

    interfaces = mkOption {
      description = "Per-interface configuration";
      default = {};
      type = with types; attrsOf (submodule ( { ... } : {

        options = {
          eapol_version = mkOption {
            type = types.int;
            default = 3;
          };

          driver = mkOption {
            type = types.enum [ "macsec_linux" "wired" ];
            default = "macsec_linux";
          };

          networks = mkOption {
            description = "Network definitions";
            default = {};
            type = with types; listOf (submodule ( { ... } : {

              options = {
                key_mgmt = mkOption {
                  description = "Choose NONE for pre-shared key authentication.";
                  type = types.enum [ "IEEE8021X" "NONE" ];
                  default = "NONE";
                };

                eapol_flags = mkOption {
                  type = types.int;
                  default = 0;
                };

                macsec_policy = mkOption {
                  type = types.bool;
                  default = false;
                };

                macsec_port = mkOption {
                  type = types.port;
                  default = 1;
                };

                macsec_replay_protect = mkOption {
                  type = types.bool;
                  default = true;
                };

                macsec_replay_window = mkOption {
                  type = types.int;
                  default = 0;
                };

                mka_cak = mkOption {
                  description = "Path to key file";
                  type = types.str;
                  default = "";
                };

                mka_ckn = mkOption {
                  description = "Key name. 32 or 64 bytes hex string.";
                  type = types.str;
                  default = "0000000000000000000000000000000000000000000000000000000000000000";
                };

                extraConfig = mkOption {
                  type = types.lines;
                  default = "";
                };
              };
            }));
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {

    systemd.services = mapAttrs' (iface: conf:
        nameValuePair "wired-supplicant-${iface}" (let
            mdevs = map (net: subsystemDevice "${iface}-macsec${toString net.macsec_port}")
              (filter (net: net.macsec_policy) conf.networks);
          in {
          after = [ (subsystemDevice iface) ] ++ mdevs;
          before = [ "network.target" ];
          wants = [ "network.target" ];
          requires = [ (subsystemDevice iface) ] ++ mdevs;
          wantedBy = [ "multi-user.target" ];
          stopIfChanged = false;

          path = [ pkgs.coreutils ];
          serviceConfig.RuntimeDirectory = "wpa_supplicant";
          serviceConfig.RuntimeDirectoryMode = "700";

          preStart = ''
            config=/run/wpa_supplicant/${iface}.conf

            echo > $config
            chmod 600 $config

            while IFS= read -r line; do
                if [[ "$line" =~ mka_cak=(.*) ]]; then
                   echo "mka_cak=$(cat ''${BASH_REMATCH[1]})" >> $config
                else
                   printf "%s\n" "$line" >> $config
                fi
            done < ${cfgFile iface conf}
          '';

          serviceConfig = {
            ExecStart = "${lib.getBin cfg.package}/bin/wpa_supplicant -i${iface} -D ${conf.driver} -c /run/wpa_supplicant/${iface}.conf";
            Restart = "always";
            Type = "simple";
          };
        })) cfg.interfaces;

    # Create systemd service for each interface, copy config file with substitute key
    # Create macsec interfaces if enabled

    networking.macsec.interfaces = listToAttrs (flatten (mapAttrsToList (iface: conf:
        (map (net: nameValuePair "${iface}-macsec${toString net.macsec_port}" {
          port = net.macsec_port;
          dev = iface;
        }) (filter (x: x.macsec_policy) conf.networks))
    ) cfg.interfaces));
  };
}
