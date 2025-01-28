{ lib, config, ... } :

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    optionalString
    types
    ;

    cfg = config.system.machine-info;
in
{
  options.system.machine-info = {
    enable = mkEnableOption "/etc/machine-info";

    prettyHostname = mkOption {
      description = "Human readable host name.";
      type = with types; nullOr str;
      default = null;
    };

    chassis = mkOption {
      description = "Chassis type";
      type = with types; nullOr (enum [ "desktop" "laptop" "convertible" "server" "tablet" "handset" "watch" "embedded" "vm" "container" ]);
      default = null;
    };

    deployment = mkOption {
      description = "Deployment environment";
      type = with types; nullOr (enum [ "development" "integration" "staging" "production" ]);
      default = null;
    };

    location = mkOption {
      description = "System location in human readable format";
      type = with types; nullOr str;
      default = null;
    };

    hardwareVendor = mkOption {
      description = "Hardware vendor";
      type = with types; nullOr str;
      default = null;
    };

    hardwareModel = mkOption {
      description = "Hardware model";
      type = with types; nullOr str;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    environment.etc."machine-info".text = ''
      ${optionalString (cfg.prettyHostname != null) "PRETTY_HOSTNAME=${cfg.prettyHostname}"}
      ${optionalString (cfg.chassis != null) "CHASSIS=${cfg.chassis}"}
      ${optionalString (cfg.deployment != null) "DEPLOYMENT=${cfg.deployment}"}
      ${optionalString (cfg.location != null) "LOCATION=${cfg.location}"}
      ${optionalString (cfg.hardwareVendor != null) "HARDWARE_VENDOR=${cfg.hardwareVendor}"}
      ${optionalString (cfg.hardwareModel != null) "HARDWARE_MODEL=${cfg.hardwareModel}"}
    '';
  };
}
