{ lib, pkgs, config, utils, ... } :

let
  inherit (lib)
  types
  mkOption
  nameValuePair
  mapAttrs';

  cfg = config.networking.macsec.interfaces;

  # We must escape interfaces due to the systemd interpretation
  subsystemDevice = interface:
    "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device";
in {
  options.networking.macsec = {
    interfaces = mkOption {
      default = {};
      description = "MACSEC devices";
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          encrypt = mkOption {
            description = "Turn on encryption";
            type = types.bool;
            default = true;
          };

          port = mkOption {
            description = "MACSEC port";
            type = types.port;
            default = 1;
          };

          dev = mkOption {
            description = "Parent interface to bind to";
            type = types.str;
          };
        };
      }));
    };

  };

  config.systemd.services = mapAttrs' (name: ifCfg:
    nameValuePair ("macsec-${name}") {
      description = "MACSEC Interface ${name}";
      wantedBy = [ "network-setup.service" (subsystemDevice ifCfg.dev) ];
      bindsTo = [(subsystemDevice ifCfg.dev)];
      partOf = [ "network-setup.service" ];
      after = [ "network-pre.target" (subsystemDevice ifCfg.dev) ];
      before = [ "network-setup.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      path = [ pkgs.iproute2 ];
      script = ''
        # Remove Dead Interfaces
        ip link show dev "${name}" >/dev/null 2>&1 && ip link delete "${name}"

        # Add new interface
        ip link add link ${ifCfg.dev} ${name} type macsec port ${toString ifCfg.port} encrypt ${if ifCfg.encrypt then "on" else "off"}
      '';
      postStop = ''
        ip link delete "${name}" || true
      '';
  }) cfg;
}
