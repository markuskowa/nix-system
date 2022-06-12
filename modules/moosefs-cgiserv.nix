{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.moosefs;

in {
###### interface
  options.services.moosefs.cgiserv = {
    enable = mkEnableOption "Moosefs web monitoring service";

    bindHost = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Bind to host (any if left empty).";
      example = "127.0.0.1";
    };

    port = mkOption {
      type = types.port;
      default = 9425;
      description = "Bind to TCP port.";
      example = "8000";
    };
  };

  config =  mkIf cfg.cgiserv.enable {
    systemd.services.mfs-cgiserv = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.moosefs}/bin/mfscgiserv -P ${toString cfg.cgiserv.port} ${optionalString (cfg.cgiserv.bindHost != null) "-H ${cfg.cgiserv.bindHost}"}";
        User = "moosefs";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/mfs 0700 moosefs moosefs"
    ];
  };
}


