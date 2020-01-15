{ config, lib, pkgs,  ...} :

with lib;

let
  cfg = config.networking.firewall;


  start = pkgs.writeScriptBin "start.sh" ''
    #!/bin/sh

    if [ $# -lt 1 ]; then
      echo ""
      echo "Create ipset matching whole countries"
      echo "Usage: `basename \$0` <country code> [country code] ..."
      exit 1
    fi

    ${pkgs.ipset}/bin/ipset create cc hash:net

    while [ $# -ge 1 ]; do
      echo "add country $1 to list"
      while read cidr; do
        ${pkgs.ipset}/bin/ipset add cc $cidr
      done < ${pkgs.ipdeny-zones}/ipv4/$1.zone
      shift
    done

    # Insert after general "white list"
    line=`iptables -L nixos-fw -vn  --line-numbers | grep ctstate | sed 's/\([0-9]\+\).*/\1/'`

    iptables -N nixos-fw-cc
    iptables -F nixos-fw-cc
    ${concatMapStringsSep "\n" (x: "iptables -A nixos-fw-cc -j ACCEPT --proto tcp --dport ${toString x}") cfg.globalTCPPorts}
    ${concatMapStringsSep "\n" (x: "iptables -A nixos-fw-cc -j ACCEPT --proto udp --dport ${toString x}") cfg.globalUDPPorts}
    iptables -A nixos-fw-cc -s 10.0.0.0/8 -j RETURN
    iptables -A nixos-fw-cc -s 192.168.0.0/16 -j RETURN
    iptables -A nixos-fw-cc -s 172.16.0.0/12 -j RETURN
    iptables -A nixos-fw-cc -m set --match-set cc src -j ${ if cfg.countryWhitelist then "RETURN" else "DROP"}
    iptables -A nixos-fw-cc -j ${ if cfg.countryWhitelist then "DROP" else "RETURN" }
    iptables -I nixos-fw $(($line+1)) -j nixos-fw-cc
  '';

  stop = pkgs.writeScriptBin "stop.sh" ''
    #!/bin/sh
    iptables -D nixos-fw-accept -j nixos-fw-cc
    iptables -F nixos-fw-cc
    iptables -X nixos-fw-cc

    ${pkgs.ipset}/bin/ipset flush cc
    ${pkgs.ipset}/bin/ipset destroy cc

  '';

in {

  options.networking.firewall = {

    countries = mkOption {
      type = with types; listOf str;
      default = [];
      example = literalExample "[ "de" "cn" ]";
      description =
        ''
          White/Black list ip ranges of whole countries
        '';
    };

    countryWhitelist = mkOption {
      type = types.bool;
      default = true;
      description =
        ''
          If true rules are applied as whitelist.
          Set to false if you want to block specific countries.
        '';
    };

    globalTCPPorts = mkOption {
      type = with types; listOf int;
      default = [];
      description = "TCP port that should be opened globally (ignore countries).";
    };

    globalUDPPorts = mkOption {
      type = with types; listOf int;
      default = [];
      description = "UDP port that should be opened globally (ignore countries).";
    };

  };

  config = mkIf (cfg.enable && lib.length cfg.countries != 0 ) {
    networking.firewall.extraCommands = ''
      ${start}/bin/start.sh ${concatStringsSep " " cfg.countries}
    '';

    networking.firewall.extraStopCommands = ''
      ${stop}/bin/stop.sh
    '';
  };
}
