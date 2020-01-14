{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.nfs-ganesha;

  cfgFile = pkgs.writeText "ganesha.conf" cfg.config;

in {
  ###### interface

  options = {
    services.nfs-ganesha = {
      enable = mkEnableOption "NFS-Ganesha server";

      config = mkOption {
        type = types.lines;
        default = null;
        description = "Contents of config file";
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {

    # Ganesha fails to register w/o even when
    # only NFSv4 is selected
    services.rpcbind.enable = true;

    systemd.services.ganesha-nfsd = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      preStart = ''
        mkdir -p /var/lib/nfs/ganesha
      '';

      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.nfs-ganesha}/bin/ganesha.nfsd -p /run/ganesha.pid -f ${cfgFile}";
      };
    };
  };
}

