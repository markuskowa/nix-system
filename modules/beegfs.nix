{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.beegfs2;

  valueToString = key: val:
    if isBool val then (if val then "${key} = true" else "${key} = false")
    else "${key} = ${toString val}";

  attrsToString = set: concatStringsSep "\n" (
    mapAttrsToList (key: val: valueToString key val) set);

  formatter = {
    type = with types; let
      valueType = oneOf [
        bool
        int
        float
        str
      ] // {
        description = "BeeGFS config file format";
      };
    in attrsOf valueType;

    generate = name: config:
      pkgs.writeText name (attrsToString config);
   };

  service = name: cfgFile: {
    wantedBy  = [ "multi-user.target" ];
    requires = [ "network-online.target" ];
    after = [
      "network-online.target"
      "zfs.target"
    ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.beegfs}/bin/beegfs-${name} cfgFile=${cfgFile} runDaemonized=false";

      # If the sysTargetOfflineTimeoutSecs in beegfs-mgmtd.conf is set over 240, this value needs to be
      # adjusted accordingly. Recommendation: sysTargetOfflineTimeoutSecs + 60
      TimeoutStopSec=300;
    };
  };

  cfgFile = service:
    formatter.generate "beegfs-${service}.conf" cfg."${service}".settings;

in {
  ###### interface

  options.services.beegfs2 = {
    mgmtd = {
      enable = mkEnableOption "BeeGFS managment daemon";

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };
    };

    meta = {
      enable = mkEnableOption "BeeGFS meta data daemon";

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };
    };

    storage = {
      enable = mkEnableOption "BeeGFS storage daemon";

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };
    };

    client = {
      enable = mkEnableOption "BeeGFS client";

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };
    };
  };


  ###### implementation

  config = mkIf (cfg.mgmtd.enable || cfg.meta.enable || cfg.storage.enable || cfg.client.enable) {

    # Systemd service defintions
    systemd.services = {
      beegfs-mgmtd = mkIf cfg.mgmtd.enable (service "mgmtd" (cfgFile "mgmtd"));

      beegfs-meta = mkIf cfg.meta.enable (service "meta" (cfgFile "meta"));

      beegfs-storage = mkIf cfg.storage.enable (service "storage" (cfgFile "storage"));

      beegfs-helperd = mkIf cfg.client.enable (service "helperd"
          (formatter.generate "beegfs-helperd.conf" cfg.client.settings));
    };

    environment.etc."beegfs/beegfs-helperd.conf" = mkIf cfg.client.enable {
      enable = true;
      source = cfgFile "client";
    };

    environment.etc."beegfs/beegfs-mgmtd.conf" = mkIf cfg.client.enable {
      enable = true;
      source = cfgFile "mgmtd";
    };

    boot.kernelModules = mkIf cfg.client.enable [
      "beegfs"
    ];

    environment.systemPackages = [ pkgs.beegfs ];
  };
}

