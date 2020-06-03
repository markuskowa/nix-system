{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.moosefs;

  mfsUser = if cfg.runAsUser then "moosefs" else "root";

  initTool = pkgs.writeShellScriptBin "mfsmaster-init" ''
    cp ${pkgs.moosefs}/var/mfs/metadata.mfs.empty ${cfg.master.dataPath}
    chmod +w ${cfg.master.dataPath}/metadata.mfs.empty
    ${pkgs.moosefs}/bin/mfsmaster -a -c ${masterCfg} start
    ${pkgs.moosefs}/bin/mfsmaster -c ${masterCfg} stop
    rm ${cfg.master.dataPath}/metadata.mfs.empty
  '';

  # master config file
  masterCfg = pkgs.writeText "mfsmaster.cfg" ''
    WORKING_USER = ${mfsUser}
    DATA_PATH = ${cfg.master.dataPath}
    EXPORTS_FILENAME=${pkgs.writeText "mfsexports.cfg"
     (concatStringsSep "\n" cfg.master.exports)}

    ${cfg.master.extraConfig}
  '';

  # metalogger config file
  metaloggerCfg = pkgs.writeText "mfsmetalogger.cfg" ''
    WORKING_USER = ${mfsUser}
    MASTER_HOST=${cfg.masterHost}
    DATA_PATH=${cfg.metalogger.dataPath}

    ${cfg.metalogger.extraConfig}
  '';

  # chunkserver config file
  chunkserverCfg = pkgs.writeText "mfschunkserver.cfg" ''
    WORKING_USER = ${mfsUser}
    MASTER_HOST=${cfg.masterHost}
    DATA_PATH=${cfg.chunkserver.dataPath}
    HDD_CONF_FILENAME=${pkgs.writeText "mfshdd.cfg"
     (concatStringsSep "\n" cfg.chunkserver.hdds)}

    ${cfg.chunkserver.extraConfig}
 '';

  # generic template for all deamons
  systemdService = name: configFile: dataPath: {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network.target" "network-online.target" ];

    # ensure data path exists and has the right permissions
    preStart = ''
      mkdir -p ${dataPath}
      chown ${mfsUser}:${mfsUser} ${dataPath}
    '';

    serviceConfig = {
      Type = "forking";
      ExecStart  = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} start";
      ExecStop   = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} stop";
      ExecReload = "${pkgs.moosefs}/bin/mfs${name} -c ${configFile} reload";
      PIDFile = "${dataPath}/.mfs${name}.lock";
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

        dataPath = mkOption {
          type = types.str;
          default = "/var/lib/mfs";
          description = "Data storage directory";
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "Master daemon extra config";
        };
      };

      metalogger = {
        enable = mkEnableOption "Moosefs metalogger daemon";

        dataPath = mkOption {
          type = types.str;
          default = "/var/lib/mfs";
          description = "Data storage directory";
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "metalogger daemon configuration file text";
        };
      };

      chunkserver = {
        enable = mkEnableOption "Moosefs chunkserver daemon";

        dataPath = mkOption {
          type = types.str;
          default = "/var/lib/mfs";
          description = "Directory for lock file";
        };

        hdds = mkOption {
          type = with types; listOf str;
          default =  null;
          description = "Mount points to be used by chunkserver for storage (see mfshdd.cfg)";
          example = [ "/mnt/hdd1" ];
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = "chunkserver daemon configuration file text";
        };
      };
    };
  };

  ###### implementation

  config =  mkIf ( cfg.client.enable || cfg.master.enable || cfg.metalogger.enable || cfg.chunkserver.enable ) {

    warnings = [ ( mkIf (!cfg.runAsUser) "Running moosefs services as root is not recommended") ];

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

    # TODO: cgiserver
    systemd.services.mfs-master = mkIf cfg.master.enable
      ( systemdService "master" masterCfg cfg.master.dataPath );

    systemd.services.mfs-metalogger = mkIf cfg.metalogger.enable
      ( systemdService "metalogger" metaloggerCfg cfg.metalogger.dataPath );

    systemd.services.mfs-chunkserver = mkIf cfg.chunkserver.enable
      ( systemdService "chunkserver" chunkserverCfg cfg.chunkserver.dataPath );
    };
}

