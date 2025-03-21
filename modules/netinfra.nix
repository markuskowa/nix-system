{ config, pkgs, lib, ... } :

let
  inherit (lib)
    mkOption
    mkIf
    types
    mapAttrs
  ;
  cfg = config.infra;

  libsys = import ../lib.nix { inherit pkgs lib; };

in {

  options.infra = {
    enable = lib.mkEnableOption "Global network configuration";

    # VLAN definitions
    vlans = mkOption {
      default = {};
      description = "List of vlans";
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          id = mkOption {
            type = types.ints.between 1 4096;
            description = "VLAN ID";
          };
          comment = mkOption {
            type = types.str;
            default = "";
          };
        };
      }));
    };

    # Global definition of network structure
    networks = mkOption {
      default = {};
      description = "List of networks";
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          subnet = mkOption {
            type = types.str;
            description = "Subnet Address";
          };

          prefixLength = mkOption {
            type = types.ints.between 1 32;
            description = "Length of netmask in number of bits";
            default = 24;
          };

          mtu = mkOption {
            type = types.ints.between 68 9000;
            description = "MTU of the subnet";
            default = 1500;
          };

          dns = mkOption {
            type = with types; listOf (strMatching "^([0-9]{1,3}\.){3}[0-9]{1,3}$");
            description = "List of DNS servers for subnet";
            default = [];
          };

          pools = mkOption {
            description = "IP pools for DHCP server";
            default = [];
            type = with types; listOf (submodule ({...} : {
              options = {
                begin = mkOption {
                  description = "First host index for pool";
                  type = types.ints.u32;
                };

                end = mkOption {
                  description = "Last host index for pool";
                  type = types.ints.u32;
                };
              };
            }));
          };

          dhcpManaged = mkOption {
            description = "Network is managed by DHCP";
            type = types.bool;
            default = false;
          };

          gateway = mkOption {
            type = types.ints.between 1 254; # FIXME: 24 bit mask
            description = "Host part of gateway address";
          };

          hosts = mkOption {
            default = {};
            description = "List of hosts";
            type = with types; attrsOf (submodule ( { ... } : {
              options = {
                hostIndex = mkOption {
                  type = types.ints.between 1 254; # FIXME: this is tied to 24 mask
                  description = "Host address part";
                };

                mac = mkOption {
                  type = with types; nullOr
                    (strMatching "[a-fA-F0-9]{2}:([a-fA-F0-9]{2}:){4}[a-fA-F0-9]{2}");

                  description = ''
                    MAC address for dhcpd entries.
                  '';
                  default = null;
                };

                dns = mkOption {
                  type = with types; nullOr str;
                  description = "DNS entry";
                  default = null;
                };

                wgPublicKey = mkOption {
                  type = with types; nullOr str;
                  description = "Wire guard public key for host.";
                  default = null;
                };
              };
            }));
          };
        };
      }));
    };

    # Host configurations
    hosts = mkOption {
      default = {};
      description = "Explicit network configuration for hosts";
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          comment = mkOption {
            type = types.str;
            default = "";
          };

          vm-host = mkOption {
            type = with types; nullOr str;
            default = null;
          };

          etcHosts = mkOption {
            type = with types; listOf str;
            description = "Generate /etc/hosts entries for given networks";
            default = [];
          };

          defaultInterface = mkOption {
            type = with types; nullOr str;
            description = "Interface to use for default gateway";
            default = null;
          };

          interfaces = mkOption {
            description = "Interface defintion";
            default = {};
            type = with types; attrsOf (submodule ( { ... } : {
              options = {
                network = mkOption {
                  type = with types; nullOr str;
                  description = "network name";
                  default = null;
                };

                vlan = {
                  name = mkOption {
                    type = with types; nullOr str;
                    description = "VLAN name to bind to";
                    default = null;
                  };

                  interface = mkOption {
                    type = with types; nullOr str;
                    description = "Physical interface to bind to";
                    default = null;
                  };
                };

                useDHCP = mkOption {
                  type = with types; nullOr bool;
                  description = "Enable DHCP client";
                  default = null;
                };
              };
            }));
          };
        };
      }));

    };

    ipByNet = mkOption {
      description = "Auto-generated host-by-name attribute set";
      type = with types; attrsOf (attrsOf str);
    };

    ipByDns = mkOption {
      description = "Auto-generated DNS style entries. This is meant to be used to generate DNS zone files.";
      type = types.anything;
    };
  };

  options.system.infra.json = mkOption {
    internal = true;
    description = "JSON file with network assets";
  };

  config = let
    systemName = config.system.name;
  in {
    assertions = [
      # index is in subnet ?
      #
    ];

    # Setup VLAN
    networking.vlans = lib.mapAttrs' (interface: icfg:
      lib.nameValuePair
        interface #icfg.vlan.name
        { interface = icfg.vlan.interface; id = cfg.vlans."${icfg.vlan.name}".id; }
      )
      (lib.filterAttrs (_: value: value.vlan.name != null) cfg.hosts."${systemName}".interfaces);

    # Interface IPs
    networking.interfaces = mapAttrs (interface: icfg:
      let
          netCfg = cfg.networks."${icfg.network}";
          host = netCfg.hosts.${systemName};
      in {
        useDHCP = mkIf (icfg.useDHCP != null) icfg.useDHCP;
        mtu = mkIf (icfg.network != null) netCfg.mtu;
        ipv4.addresses = mkIf (icfg.network != null) [{
          inherit (netCfg) prefixLength;
          address = libsys.genAddress netCfg.subnet host.hostIndex;
        }];
      })
      (lib.filterAttrs (_: value: value.network != null) cfg.hosts."${systemName}".interfaces);

    # Set default gateway
    networking.defaultGateway = mkIf (cfg.hosts."${systemName}".defaultInterface != null )
    (let
      defaultInterface = cfg.hosts.${systemName}.defaultInterface;
      network = cfg.networks.${cfg.hosts.${systemName}.interfaces.${defaultInterface}.network};
    in {
      interface = defaultInterface;
      address = libsys.genAddress network.subnet network.gateway;
    });

    # Generate IPs by hostname
    infra.ipByNet = mapAttrs (netname: net:
        mapAttrs (hostname: host:
          libsys.genAddress net.subnet host.hostIndex
    ) net.hosts
    ) cfg.networks;

    # Generate DNS-style mapping
    infra.ipByDns = lib.foldl
      (left: entry: lib.recursiveUpdate left (lib.setAttrByPath entry.name entry.value)) {}
      (map (x:
        {
          name = lib.reverseList (lib.splitString "." x.dns_.name);
          value.A = x.dns_.value;
        }
        )
        (lib.collect (x: x ? dns_)
          (mapAttrs (netname: net:
            mapAttrs (hostname: host: {
              dns_ = { name = "${host.dns}"; value = libsys.genAddress net.subnet host.hostIndex; };
            }
          ) (lib.filterAttrs (_: x: x.dns != null) net.hosts) # map hosts
          ) cfg.networks))); # map networks

    # Generate /etc/hosts
    networking.hosts = lib.mergeAttrsList (
        map (network:
          lib.mapAttrs' (host: x: {
              name = libsys.genAddress cfg.networks.${network}.subnet x.hostIndex;  # IP address
              value = [(if (x.dns != null) then x.dns else "${host}.${network}")]; # hostname
            }
          ) cfg.networks.${network}.hosts
        )
      cfg.hosts."${systemName}".etcHosts)
    ;


    system.infra.json = pkgs.writeText "infrastructure.json" (builtins.toJSON config.infra);
  };
}
