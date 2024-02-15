{ config, lib, pkgs, utils, ... }:

with lib;

let
  cfg = config.networking.vxlans;

  # We must escape interfaces due to the systemd interpretation
  subsystemDevice = interface:
    "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device";


in {
###### interface
  options.networking.vxlans = mkOption {
    default = {};
    description = "List of networks and hosts";
    type = with types; attrsOf (submodule ( { ... } : {
      options = {
        id = mkOption {
          description = "VLAN id";
          type = types.ints.between 0 16777214;
          default = 0;
        };

        local = mkOption {
          description = "Local IP address";
          type = with types; nullOr str;
          default = null;
        };

        remote = mkOption {
          description = "Remote IP address";
          type = with types; nullOr str;
          default = null;
        };

        group = mkOption {
          description = "Multicast group";
          type = types.str;
          default = "239.1.1.1";
        };

        port = mkOption {
          description = "UDP port";
          type = types.port;
          default = 4789;
        };

        dev = mkOption {
          type = with types; nullOr str;
          description = "Physical interface to bind to";
          default = null;
        };

        extraOptions = mkOption {
          type = with types; str;
          description = "Extra options for 'ip link add'";
          default = "";
        };
      };
    }));
  };

  config.systemd.services = mapAttrs' (name: net:
    nameValuePair ("vxlan-${name}") {
      description = "VXLAN Interface ${name}";
      wantedBy = [ "network-setup.service" ] ++ optional (net.dev != null) (subsystemDevice net.dev);
      bindsTo = optional (net.dev != null) (subsystemDevice net.dev);
      partOf = [ "network-setup.service" ];
      after = [ "network-pre.target" ] ++ optional (net.dev != null) (subsystemDevice net.dev);
      before = [ "network-setup.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      path = [ pkgs.iproute2 ];
      script = ''
        # Remove Dead Interfaces
        ip link show dev "${name}" >/dev/null 2>&1 && ip link delete "${name}"

        # Add new interface
        ip link add ${name} type vxlan id ${toString net.id} ${optionalString (net.local != null) "local ${net.local}"} \
          ${optionalString (net.remote == null) "group ${net.group}"} ${optionalString (net.remote != null) "remote ${net.remote}"} \
          dstport ${toString net.port} \
          dev ${net.dev} ${net.extraOptions}
      '';
      postStop = ''
        ip link delete "${name}" || true
      '';
  }) cfg;
}
