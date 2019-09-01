{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.orangefs.client;

in {
  ###### interface

  options = {
    services.orangefs.client = {
      enable = mkEnableOption "OrangeFS client daemon";

      extraOptions = mkOption {
        type = types.str;
        default = "";
        description = "Extra command line options for pvfs2-client.";
      };

      fileSystems = mkOption {
        type = with types; listOf (submodule ({ ... } : {
          options = {

            mountPoint = mkOption {
              type = types.str;
              default = "/orangefs";
              description = "Mount point.";
            };

            options = mkOption {
              type = with types; listOf str;
              default = [];
              description = "Mount options";
            };

            target = mkOption {
              type = types.str;
              default = null;
              example = "tcp://server:3334/orangefs";
              description = "Target URL";
            };
          };
        }));
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.orangefs ];

    boot.supportedFilesystems = [ "pvfs2" ];
    boot.kernelModules = [ "orangefs" ];

    systemd.services.orangefs-client = {
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # Let service settle after network is online
      # and before mounts are done.
      # Otherwise client daemon may hang.
      preStart = "sleep 1";
      postStart = "sleep 1";

      serviceConfig = {
        Type = "forking";

        ExecStart = ''
          ${pkgs.orangefs}/bin/pvfs2-client ${cfg.extraOptions} \
             --logtype=syslog \
             -p ${pkgs.orangefs}/bin/pvfs2-client-core
        '';
        TimeoutStopSec = "120";
      };
    };

    systemd.mounts = map (fs: {
      requires = [ "orangefs-client.service" ];
      after = [ "orangefs-client.service" ];
      bindsTo = [ "orangefs-client.service" ];
      wantedBy = [ "remote-fs.target" ];
      type = "pvfs2";
      options = concatStringsSep "," fs.options;
      what = fs.target;
      where = fs.mountPoint;
    }) cfg.fileSystems;
  };
}

