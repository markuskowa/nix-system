{ lib, pkgs, config, utils, ... } :


let
  inherit (lib)
  types
  optionalString
  mkOption
  mkEnableOption
  mkIf;

  cfg = config.services.hostapd-wired;

in {
  options.services.hostapd-wired = {
    enable = mkEnableOption "Wired hostapd";
    interface = mkOption {
      type = types.str;
      default = null;
    };

    driver = mkOption {
      type = with types; enum [ "wired" "macsec_linux" ];
      default = "wired";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hostapd-wired = let
      configFile = pkgs.writeText "hostapd-wired.conf" ''
        ctrl_interface=/run/hostapd
        ctrl_interface_group=root

        interface=${cfg.interface}
        driver=${cfg.driver}

        ${cfg.extraConfig}
      '';

    in {
      path = [ pkgs.hostapd ];
      requires = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        RuntimeDirectory="hostapd";
        ExecStart = "${pkgs.hostapd}/bin/hostapd ${configFile}";
        Restart = "always";
        Type = "simple";
      };
    };
  };
}
