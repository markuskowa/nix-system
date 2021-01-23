{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.isnsd;

  settingsFormat = pkgs.formats.keyValue {
    trueVal = "1";
    falseVal = "0";
  };

in {
  ###### interface

  options = {
    services.isnsd = {
      enable = mkEnableOption "iSNS daemon";

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;

          options = {
            SourceName = mkOption {
              type = types.str;
              description = "Initiator name.";
              example = "iqn.2004-01.org.nixos.san:initiator";
              default = "iqn.2004-01.org.nixos.san:${config.networking.hostName}";
            };

            DefaultDiscoveryDomain = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Create a default discovery domain
              '';
            };
          };
        };

        default = { };

        description = "Contents of config file (isnsd.conf)";
      };

      registerControl = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Register localhost as control node.
        '';
      };

      discoveryDomains = mkOption {
        type = with types; attrsOf (listOf str);
        description = "Create discovery domains and add members on startup.";
        default = {};
        example = {
          domain1 = [
            "iqn.2004-01.org.nixos.san:server1"
            "iqn.2004-01.org.nixos.san:client1"
          ];
          domain2 = [
            "iqn.2004-01.org.nixos.san:server2"
            "iqn.2004-01.org.nixos.san:client2"
          ];
        };
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.openisns ];

    environment.etc."isns/isnsadm.conf" = {
      text = "";
    };

    systemd.services = let
      isnsdConf = settingsFormat.generate "isnsd.conf" cfg.settings;
    in {
      isnsd = {
        after = [ "network.target" ];
        before = [ "iscsid.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.openisns}/bin/isnsd -f -c ${isnsdConf}";
        };

        postStart = ''
          sleep 1
          ${optionalString cfg.registerControl "${pkgs.openisns}/bin/isnsadm --local --register control"}

          ${concatStringsSep "\n" (mapAttrsToList (name: members:
              "${pkgs.openisns}/bin/isnsadm --local --dd-register dd-name=${name} " +
                (concatMapStringsSep " " (member-name: "member-name=${member-name}") members)
            ) cfg.discoveryDomains )
          }
        '';
      };
    };
  };
}
