{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zfs.datasets;
in
{
  ###### interface

  options = {
    services.zfs.datasets = mkOption {
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
      type = with types; attrsOf attrs;
    };
  };

  ###### implementation

  config = {
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
            mapAttrsToList ( pool: prop:
              mapAttrsToList ( prop: val:
                "zfs set ${prop}=${val} ${pool}"
              ) prop
            ) cfg
          ))
        }
      '';
    };
  };
}
