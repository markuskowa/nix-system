{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.boot.initrd.iscsi;

in {
  ###### interface

  options = {
    boot.initrd.iscsi = {
      enable = mkEnableOption "iSCSI devices in initrd";

      ibft = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If you have an iBFT capable firmware, iscsistart can
          obtain the initiator and target information from /sys/firmware/ibft.
        '';
      };

      initiatorName = mkOption {
        type = with types; nullOr (strMatching
          "[iI][qQ][nN][.][0-9]{4}-[0-9]{2}[.][a-zA-Z0-9.-]+(:[a-zA-Z0-9.-]*)?");
        description = "Initiator name.";
        example = "iqn.2004-01.org.nixos.san:initiator";
        default = "iqn.2004-01.org.nixos.san:${config.networking.hostName}";
      };

      devices = mkOption {
        default = [];
        type = with types; listOf (submodule {
          options = {
            target = mkOption {
              type = types.str;
              default = null;
              description = "Target IQN.";
            };

            address = mkOption {
              type = types.str;
              default = null;
              description = "Target IP address";
            };

            portalGroup = mkOption {
              type = types.int;
              default = 1;
              description = "Portal group index.";
            };

            extraOpts = mkOption {
              type = types.str;
              default = "";
              description = "Extra options for iscsistart";
            };
          };
        });
      };
    };
  };

  ###### implementation

  config = mkIf ( cfg.enable && config.boot.initrd.enable ) {
    # assert dhcpd is enabled
    # assert initiator name is not set twice
    # assert if ibft then initiator name is not set

    assertions = [
      {
        assertion = config.networking.dhcpcd.enable;
        message = "iSCSI at boot is only implemented for dhcpcd.";
      }
      {
        assertion = cfg.ibft || cfg.initiatorName != null;
        message = "You must either set the initiatorName or use iBFT.";
      }
    ];

    # optimization params for iscsid?

    # needed for a clean shutdown
    networking.dhcpcd.persistent = true;

    services.iscsid = {
      enable = true;
      initiatorName = mkIf (!cfg.ibft) cfg.initiatorName;
    };

    boot.initrd.kernelModules = [ "iscsi_tcp" ]
      ++ optional cfg.ibft "iscsi_ibft";

    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.openiscsi}/bin/iscsistart
    '';

    boot.initrd = {
      network.enable = true;

      preLVMCommands = optionalString cfg.ibft ''
        echo "Logging in into iSCSI with iBFT parameters"

        iscsistart -b
      '' + concatStringsSep "\n" ( map ( x: ''
        echo "Logging in into iSCSI target: ${x.target}"

        iscsistart \
          ${if cfg.ibft then "-i $(cat /sys/firmware/ibft/initiator/initiator-name)"
           else "-i ${cfg.initiatorName}"} \
          -t ${x.target} \
          -a ${x.address} \
          -g ${toString x.portalGroup} \
          ${x.extraOpts}
      '') cfg.devices );
    };
  };
}
