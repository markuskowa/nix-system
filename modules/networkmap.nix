{ config, lib, ... } :

with lib;

let
  cfg = config.networking;

  genHostName = net: host:
    if host.name != null
    then host.name
    else (net.prefix + toString host.node);

in {

  ###### interface

  options.networking.db = {
    enable = mkEnableOption "network map DB";

    networks = mkOption {
      default = {};
      description = "List of networks and hosts";
      type = with types; attrsOf (submodule ( { ... } : {
        options = {
          prefix = mkOption {
            type = with types; nullOr str;
            description = "Prefix used for automatic name generation";
            default = null;
          };

          subnet = mkOption {
            type = types.str;
            description = "FIXME: 24 bit subnet (first three octets)";
            default = null;
          };

          mtu = mkOption {
            type = types.int;
            description = "MTU of the subnet";
            default = 1500;
          };

          enableDhcpd = mkOption {
            type = types.bool;
            default = false;
            description = "Generate machine entries for dhpcd";
          };

          enableEtcHosts = mkOption {
            type = types.bool;
            default = false;
            description = "Generate /etc/hosts entries";
          };

          machList = mkOption {
            type = types.listOf (types.submodule ({ prefix , node, ...} : {
              options = {
                node = mkOption {
                  type = with types; int;
                  description = ''
                    Sequence number. Becomes host address if given.
                  '';
                  default = null;
                };

                mac = mkOption {
                  type = with types; nullOr
                    (strMatching "[a-fA-F0-9]{2}:([a-fA-F0-9]{2}:){4}[a-fA-F0-9]{2}");

                  description = ''
                    MAC address for dhcpd entries.
                  '';
                  default = null;
                };

                name = mkOption {
                  type = with types; nullOr str;
                  #apply = name: if name != null
                  #  then name
                  #  else (prefix + toString node);

                  description = ''
                    Hostname. Will be generated automatically if not given.
                  '';
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

    hosts = mkOption {
      description = "Auto-generated host-by-name attribute set";
      type = with types; attrsOf str;
    };
  };

  ###### implementation

  config = mkIf cfg.db.enable {
    # generate dhcpd entries
    services.dhcpd4.machines = flatten ( mapAttrsToList ( netName: net:
      map ( host: {
        ethernetAddress = host.mac;
        hostName = genHostName net host;
        ipAddress = "${net.subnet}.${toString host.node}";
      }) ( filter (x: x.mac != null) net.machList )
    ) (filterAttrs (n: v: v.enableDhcpd) cfg.db.networks) );

    # generate /etc/hosts entries
    networking.hosts =
      let
        genHosts = net: ( zipAttrs ( map ( host: {
          "${net.subnet}.${toString host.node}" = genHostName net host;
        }) net.machList) );

      in foldAttrs (l: a: l ++ a) [] (
        mapAttrsToList (netName: net: genHosts net)
        (filterAttrs (n: v: v.enableEtcHosts) cfg.db.networks)
      );

    # Generate host-by-name attribute set
    networking.db.hosts = listToAttrs (flatten ( mapAttrsToList ( netName: net:
        map ( host:
                      #name =   value=ip
          nameValuePair
            (genHostName net host)
            (net.subnet + "." + toString host.node)
      ) net.machList
    ) cfg.db.networks));

  };

}

