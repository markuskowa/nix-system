{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zfs.datasets;
in
{
  ###### interface

  options = {
    services.zfs.datasets = {
      enable = mkEnableOption "declarative ZFS dataset properties";
      properties = mkOption {
        description = ''
          Declarative ZFS dataset properties
          ZFS dataset property value for <literal>zfs set</literal>
        '';
        example = ''
          {
            "rpool/home"."com.sun:auto-snapshot" = "true";
            "rpool/root".quota = "100G";
          }
        '';
        default = {};
        type = with types; attrsOf (attrsOf str);
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    systemd.services.zfs-datasets = {
      path = with pkgs; [ zfs ];

      restartIfChanged = true;

      wantedBy = [ "local-fs.target" ];
      requires = [ "zfs.target" ];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        ${
          concatStringsSep "\n" ( flatten (
            mapAttrsToList ( ds: prop:
              mapAttrsToList ( key: val: ''
                if [ `zfs get -H ${key} ${ds} | ${pkgs.gawk}/bin/awk '{ print $3 }'` != "${val}" ]; then
                  zfs set ${key}=${val} ${ds}
                fi
              ''
              ) prop
            ) cfg.properties
          ))
        }
      '';
    };
  };
}
