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
      pkgs.writeText name ((attrsToString config) + "\n");
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
      ExecStart = "${pkgs.beegfs}/bin/beegfs-${name} cfgFile=${cfgFile}";

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
    mgmtdHost = mkOption {
      type = types.str;
      default = "";
      description = "Default setting for management host";
    };

    connAuthFile = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Path to shared secret";
    };

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

      mountPoint = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "If set, filesystem will be mounted here";
        example = "/beegfs";
      };

      mountOptions = mkOption {
        type = with types; str;
        default = "";
        description = "Additional mount options";
        example = "noatime";
      };

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };

      helperd.settings = mkOption {
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
          (formatter.generate "beegfs-helperd.conf" cfg.client.helperd.settings));
    };

    # Set some defaults for config files
    services.beegfs2.mgmtd.settings = {
      runDaemonized = false;
      connAuthFile = mkIf (cfg.connAuthFile != null) cfg.connAuthFile;
    };

    services.beegfs2.meta.settings = {
      sysMgmtdHost = mkDefault cfg.mgmtdHost;
      runDaemonized = false;
      connAuthFile = mkIf (cfg.connAuthFile != null) cfg.connAuthFile;
    };

    services.beegfs2.storage.settings = {
      sysMgmtdHost = mkDefault cfg.mgmtdHost;
      runDaemonized = false;
      connAuthFile = mkIf (cfg.connAuthFile != null) cfg.connAuthFile;
    };

    services.beegfs2.client.settings = {
      sysMgmtdHost = mkDefault cfg.mgmtdHost;
      connAuthFile = mkIf (cfg.connAuthFile != null) cfg.connAuthFile;
    };

    services.beegfs2.client.helperd.settings = {
      sysMgmtdHost = mkDefault cfg.mgmtdHost;
      runDaemonized = false;
      connAuthFile = mkIf (cfg.connAuthFile != null) cfg.connAuthFile;
    };

    systemd.mounts = mkIf (cfg.client.mountPoint != null)
    [{
      what = "beegfs_nodev";
      where = cfg.client.mountPoint;
      type = "beegfs";
      options = "cfgFile=${cfgFile "client"},_netdev"  + "," +  cfg.client.mountOptions;
      requires = [ "beegfs-helperd.service" "network-online.target" ];
      after = [ "beegfs-helperd.service" ];
      wantedBy = [ "multi-user.target" ];
    }];

    # Needed by command line tools
    environment.etc."beegfs/beegfs-client.conf" = mkIf cfg.client.enable {
      enable = true;
      source = cfgFile "client";
    };

    boot.kernelPackages = mkIf cfg.client.enable pkgs.linuxPackages_5_10;
    boot.extraModulePackages = mkIf cfg.client.enable [
      (pkgs.linuxPackages_5_10.beegfs)
    ];

    boot.kernelModules = mkIf cfg.client.enable [ "beegfs" ];

    environment.systemPackages = [ pkgs.beegfs ];

    nixpkgs.overlays = mkIf cfg.client.enable [(
        self: super: {
#          beegfs-modules = config.boot.kernelPackages.beegfs.override { kernel = config.boot.kernelPackages.kernel; };
    })];
  };
}

