{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.nfs-ganesha;

  attrsToString = set: concatStringsSep "\n" (
    mapAttrsToList (key: val: valueToString key val) set );

  valueToString = key: val:
    if isList val then concatStringsSep "," (map (x: valueToString x) val)
    else if isAttrs val then "${key} {\n${attrsToString val}\n}"
    else if isBool val then (if val then "true" else "false")
    else "${key} = ${toString val};";

  formatter = {
    type = with types; let
      valueType = oneOf [
        bool
        int
        float
        str
        (listOf valueType)
        (attrsOf valueType)
      ] // {
        description = "Ganesha config file format";
      };
    in attrsOf (attrsOf valueType);

    generate = name: value:
      pkgs.writeText name (attrsToString value);
   };

in {
  ###### interface

  options = {
    services.nfs-ganesha = {
      enable = mkEnableOption "NFS-Ganesha server";

      settings = mkOption {
        type = formatter.type;
        default = {};
        description = "Contents of config file";
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {

    # Ganesha fails to register w/o even when
    # only NFSv4 is selected
    services.rpcbind.enable = true;

    # Default settings
    services.nfs-ganesha.settings = {
      NFS_CORE_PARAM = {
        Enable_UDP = false;
      };

      NFS_KRB5 = {
        Active_krb5 = false;
      };

      EXPORT_DEFAULTS = {
        SecType = "sys";
        Protocols = "V4";
      };
    };

    # Service defintion
    systemd.services.ganesha-nfsd = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      preStart = ''
        mkdir -p /var/lib/nfs/ganesha
      '';

      serviceConfig = {
        RuntimeDirectory = "nfs-ganesha";
        Type = "forking";
        ExecStart = "${pkgs.nfs-ganesha}/bin/ganesha.nfsd -p /run/nfs-ganesha/ganesha.pid -f ${
          formatter.generate "ganesha.conf" cfg.settings}";
      };
    };
  };
}

