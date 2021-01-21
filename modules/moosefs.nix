{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.moosefs;

  mfsUser = if cfg.runAsUser then "moosefs" else "root";

  settingsFormat = pkgs.formats.keyValue {
    trueVal = "1";
    falseVal = "0";
  };

  initTool = pkgs.writeShellScriptBin "mfsmaster-init" ''
    cp ${pkgs.moosefs}/var/mfs/metadata.mfs.empty ${cfg.master.settings.DATA_PATH}
    chmod +w ${cfg.master.settings.DATA_PATH}/metadata.mfs.empty
    ${pkgs.moosefs}/bin/mfsmaster -a -c ${masterCfg} start
    ${pkgs.moosefs}/bin/mfsmaster -c ${masterCfg} stop
    rm ${cfg.master.settings.DATA_PATH}/metadata.mfs.empty
  '';

  # master config file
  masterCfg = settingsFormat.generate
    "mfsmaster.cfg" cfg.master.settings;

  # metalogger config file
  metaloggerCfg = settingsFormat.generate
    "mfsmetalogger.cfg" cfg.metalogger.settings;

  # chunkserver config file
  chunkserverCfg = settingsFormat.generate
    "mfschunkserver.cfg" cfg.chunkserver.settings;

  # generic template for all deamons
  systemdService = name: configFile: {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network.target" "network-online.target" ];

    # ensure data path exists and has the right permissions
    #preStart = ''
    #  mkdir -p ${dataPath}
    #  chown ${mfsUser}:${mfsUser} ${dataPath}
    #'';

    serviceConfig = {
      Type = "forking";
      ExecStart  = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} start";
      ExecStop   = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} stop";
      ExecReload = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} reload";
      #PIDFile = "${dataPath}/.mfs${name}.lock";
      TimeOutStartSec = 300;
      TimeOutStopSec = 300;
    };
  };

in {
  ###### interface

  options = {
    services.moosefs = {
      masterHost = mkOption {
        type = types.str;
        default = null;
        description = "Master host";
      };

      runAsUser = mkOption {
        type = types.bool;
        default = true;
        example = true;
        description = "Run daemons as user moosefs instead of root";
      };

      client.enable = mkEnableOption "Moosefs client";

      master = {
        enable = mkEnableOption "Moosefs master daemon";

        exports = mkOption {
          type = with types; listOf str;
          default = null;
          description = "Paths to export (see mfsexports.cfg)";
          example = [
            "* / rw,alldirs,admin,maproot=0:0"
            "* . rw"
          ];
        };

        settings = mkOption {
          type = types.submodule {
            freeformType = settingsFormat.type;

            options.DATA_PATH = mkOption {
              type = types.str;
              default = "/var/lib/mfs";
              description = "Data storage directory";
            };
          };

          description = "Contents of config file (mfsmaster.cfg)";
        };
      };

      metalogger = {
        enable = mkEnableOption "Moosefs metalogger daemon";

        settings = mkOption {
          type = types.submodule {
            freeformType = settingsFormat.type;

            options.DATA_PATH = mkOption {
              type = types.str;
              default = "/var/lib/mfs";
              description = "Data storage directory";
            };
          };

          description = "Contents of metalogger config file (mfsmetalogger.cfg)";
        };
      };

      chunkserver = {
        enable = mkEnableOption "Moosefs chunkserver daemon";

        hdds = mkOption {
          type = with types; listOf str;
          default =  null;
          description = "Mount points to be used by chunkserver for storage (see mfshdd.cfg)";
          example = [ "/mnt/hdd1" ];
        };

        settings = mkOption {
          type = types.submodule {
            freeformType = settingsFormat.type;

            options.DATA_PATH = mkOption {
              type = types.str;
              default = "/var/lib/mfs";
              description = "Directory for lock file";
            };
          };

          description = "Contents of chunkserver config file (mfschunkserver.cfg)";
        };
      };
    };
  };

  ###### implementation

  config =  mkIf ( cfg.client.enable || cfg.master.enable || cfg.metalogger.enable || cfg.chunkserver.enable ) {

    warnings = [ ( mkIf (!cfg.runAsUser) "Running moosefs services as root is not recommended") ];

    # Service settings
    services.moosefs = {
      master.settings = {
        WORKING_USER = mfsUser;
        EXPORTS_FILENAME = toString ( pkgs.writeText "mfsexports.cfg"
          (concatStringsSep "\n" cfg.master.exports));
      };

      metalogger.settings = {
        WORKING_USER = mfsUser;
        MASTER_HOST = cfg.masterHost;
      };

      chunkserver.settings = {
        WORKING_USER = mfsUser;
        MASTER_HOST = cfg.masterHost;
        HDD_CONF_FILENAME = toString ( pkgs.writeText "mfshdd.cfg"
          (concatStringsSep "\n" cfg.chunkserver.hdds));
      };
    };

    # Create system user account for daemons
    users = mkIf (cfg.runAsUser) {
      extraUsers.moosefs = {
        isSystemUser = true;
        description = "moosefs daemon user";
        group = "moosefs";
      };
      extraGroups.moosefs = {};
    };

    environment.systemPackages =
      (lib.optional cfg.client.enable pkgs.moosefs) ++
      (lib.optional cfg.master.enable initTool);

    # Create
    systemd.tmpfiles.rules =
         optional cfg.master.enable "v ${cfg.master.settings.DATA_PATH} 0700 ${mfsUser} ${mfsUser}"
      ++ optional cfg.metalogger.enable "v ${cfg.metalogger.settings.DATA_PATH} 0700 ${mfsUser} ${mfsUser}"
      ++ optional cfg.chunkserver.enable "v ${cfg.chunkserver.settings.DATA_PATH} 0700 ${mfsUser} ${mfsUser}";

    # TODO: cgiserver
    systemd.services.mfs-master = mkIf cfg.master.enable
      ( systemdService "master" masterCfg );

    systemd.services.mfs-metalogger = mkIf cfg.metalogger.enable
      ( systemdService "metalogger" metaloggerCfg );

    systemd.services.mfs-chunkserver = mkIf cfg.chunkserver.enable
      ( systemdService "chunkserver" chunkserverCfg );
    };
}

