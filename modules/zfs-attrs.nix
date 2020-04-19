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
          Declarative ZFS dataset properties.
          ZFS dataset property value for <literal>zfs set</literal>.
          zfs filesystem is created if it does not exist.

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
        dsList=(${toString (lib.mapAttrsToList (ds: prop: "${ds}") cfg.properties)})

        # Create datasets if neccesary
        for ds in "''${dsList[@]}"; do
          res=$(zfs list "$ds" 2> /dev/null > /dev/null || echo create)
          if [ "$res" == "create" ]; then
            echo "creating $s"
            zfs create "$ds"
          fi
        done


        ${
          concatStringsSep "\n" ( flatten (
            mapAttrsToList ( ds: prop:
              mapAttrsToList ( key: val: ''
                if [ $(zfs get -H ${key} ${ds} | ${pkgs.gawk}/bin/awk '{ print $3 }') != "${val}" ]; then
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
