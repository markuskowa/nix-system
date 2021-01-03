{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.iscsiTarget;

in {
  ###### interface

  options = {
    services.iscsiTarget = {
      enable = mkEnableOption "iSCSI LIO target";

      isns = {
        enable = mkEnableOption "iSNS service for LIO target";
        server = mkOption {
          type = types.str;
          default = null;
          description = "iSNS server";
        };
      };

      config = mkOption {
        type = with types; nullOr attrs;
        default = null;
        description = ''
          The config will be converted to JSON for targetcli.
          If ommited imperative state is used.
        '';
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.targetcli ]
      ++ optional cfg.isns.enable pkgs.targetisns;

    systemd.tmpfiles.rules = [
      "v /etc/target - - - - -"
    ];

    boot.kernelModules = [ "configfs" ];

    systemd.services = {
      iscsiTarget = {
        path = with pkgs; [ kmod util-linux ];
        after = [ "network.target" "local-fs.target" "sys-kernel-config.mount" ];
        requires = [ "sys-kernel-config.mount" "targetclid.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.pythonPackages.rtslib}/bin/targetctl restore ${optionalString (cfg.config != null) "${pkgs.writeText "targetcli.json" (toJSON cfg.config)}"}";
          ExecStop = "${pkgs.pythonPackages.rtslib}/bin/targetctl clear";
          RemainAfterExit=true;
        };
      };

      targetclid = {
        after = [ "network.target" "sys-kernel-config.mount"];
        before = [ "remote-fs-pre.target" ];
        requires = [ "sys-kernel-config.mount"  "modprobe@configfs.service" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.targetcli}/bin/targetclid";
          Restart = "on-failure";
        };
      };

      target-isns = mkIf cfg.isns.enable {
        after = [ "network.target" "iscsiTarget.service" ];
        wantedBy = [ "remote-fs.target" ];
        requires = [ "targetclid" ];
        bindsTo = [ "targetclid" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.targetisns}/bin/target-isns -f -i ${cfg.isns.server}";
        };
      };
    };

    systemd.sockets.targetlcid = {
      listenStreams = [ "/run/targetclid.sock" ];
      socketConfig = { SocketMode = "0600"; };
      wantedBy = [ "sockets.target" ];
    };
  };
}
