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
          description = "Physical interface to bind to";
          type = types.str;
        };
      };
    }));
  };

  config.systemd.services = mapAttrs' (name: net:
    nameValuePair ("vxlan-${name}") {
      description = "VXLAN Interface ${name}";
      wantedBy = [ "network-setup.service" (subsystemDevice net.dev) ];
      bindsTo = [(subsystemDevice net.dev)];
      partOf = [ "network-setup.service" ];
      after = [ "network-pre.target" (subsystemDevice net.dev) ];
      before = [ "network-setup.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      path = [ pkgs.iproute2 ];
      script = ''
        # Remove Dead Interfaces
        ip link show dev "${name}" >/dev/null 2>&1 && ip link delete "${name}"

        # Add new interface
        ip link add ${name} type vxlan id ${toString net.id} group ${net.group} dstport ${toString net.port} dev ${net.dev}
      '';
      postStop = ''
        ip link delete "${name}" || true
      '';
  }) cfg;
}
