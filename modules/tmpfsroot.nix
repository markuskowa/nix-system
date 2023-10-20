{ config, pkgs, lib, ... } :

with lib;

let
  cfg = config.system.tmpfsroot;

in {

  ### Interface

  options = {
    system.tmpfsroot = {
      enable = mkEnableOption "tmpfs root";

      size = mkOption {
        type = types.str;
        default = "256M";
	description = "Size of root tmpfs";
      };

      persistPath = mkOption {
        type = types.str;
        default = "/nix/persist";
        description = ''
          Path to store persistent data.
        '';
      };

      etcNixos = mkOption {
	type = types.bool;
        default = true;
	description = "Enable persistent /etc/nixos";
      };

      fixMachineId = mkOption {
	type = types.bool;
        default = false;
        description = ''
          Provide a persistend machine-id file in $persistPath/etc.
          Use this option if you are keeping the journal acros reboots.
        '';
      };
    };
  };

  ### Implementation

  config = mkIf cfg.enable {

    users.mutableUsers = mkDefault false;

    fileSystems."/" = mkDefault {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "mode=755" "size=${cfg.size}" ];
    };

    boot.tmp.useTmpfs = mkDefault true;

    environment.etc."machine-id" = mkIf cfg.fixMachineId {
      source = "${cfg.persistPath}/etc/machine-id";
    };

    systemd.tmpfiles.rules = [
    ] ++ optionals cfg.etcNixos [
      "d  ${cfg.persistPath}/etc/nixos - - - - -"
      "L+ /etc/nixos - - - - ${cfg.persistPath}/etc/nixos"
    ] ++ optionals config.services.openssh.enable [
      "d ${cfg.persistPath}/keys/ssh  - - - - -"
    ];

    services.openssh = mkIf config.services.openssh.enable {
      hostKeys = mkDefault [
        { "bits" = 4096;
          "path" = "${cfg.persistPath}/keys/ssh/ssh_host_rsa_key";
          "type" = "rsa";
        }
        { "path" = "${cfg.persistPath}/keys/ssh/ssh_host_ed25519_key";
          "type" = "ed25519";
        }
      ];

      extraConfig = ''
        HostCertificate ${cfg.persistPath}/keys/ssh/ssh_host_rsa_key-cert.pub
        HostCertificate ${cfg.persistPath}/keys/ssh/ssh_host_ed25519_key-cert.pub
      '';
    };
  };
}
