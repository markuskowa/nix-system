{ lib, pkgs, config, utils, ... } :


let
  inherit (lib)
  types
  optionalString
  mkOption
  mkEnableOption
  mkIf;

  cfg = config.services.hostapd-radius;

in {

  options.services.hostapd-radius = {
    enable = mkEnableOption "hostapd radius server";

    auth_port = mkOption {
      type = types.port;
      default = 1812;
    };

    acct_port = mkOption {
      type = types.port;
      default = 1813;
    };

    clients_file = mkOption {
      type = with types; str;
      default = [];
    };

    eap_user_file = mkOption {
      type = with types; str;
      default = [];
    };

    ca_cert = mkOption {
      type = with types; nullOr str;
      default = null;
    };

    server_cert = mkOption {
      type = with types; nullOr str;
      default = null;
    };

    private_key = mkOption {
      type = with types; nullOr str;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hostapd-radius = let
      configFile = pkgs.writeText "hostapd-radius.conf" ''
        driver=none

        eap_server=1
        eap_user_file=${cfg.eap_user_file}

        radius_server_clients=${cfg.clients_file}
        radius_server_auth_port=${toString cfg.auth_port}
        radius_server_acct_port=${toString cfg.acct_port}

        ${optionalString (cfg.ca_cert !=null) "ca_cert=cfg.${cfg.ca_cert}"}
        ${optionalString (cfg.server_cert !=null) "server_cert=cfg.${cfg.server_cert}"}
        ${optionalString (cfg.private_key !=null) "server_cert=cfg.${cfg.private_key}"}
      '';

    in {
      path = [ pkgs.hostapd ];
      requires = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.hostapd}/bin/hostapd ${configFile}";
        Restart = "always";
        Type = "simple";
      };
    };
  };
}

