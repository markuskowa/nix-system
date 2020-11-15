{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.iscsiTarget;

in {
  ###### interface

  options = {
    services.iscsiTarget = {
      enable = mkEnableOption "iSCSI LIO target";
    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.targetcli ];

    systemd.tmpfiles.rules = [
      "v /etc/target - - - - -"
    ];

    boot.kernelModules = [ "configfs" ];

    systemd.services = {
      iscsiTarget = {
        path = [ pkgs.kmod ];
        after = [ "network.target" "local-fs.target" "sys-kernel-config.mount" ];
        requires = [ "sys-kernel-config.mount" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.pythonPackages.rtslib}/bin/targetctl restore";
          RemainAfterExit=true;
        };
      };

      targetclid = {
        after = [ "network.target" "sys-kernel-config.mount" ];
        before = [ "remote-fs-pre.target" ];
        wantedBy = [ "multi-user.target" ];
        requires = [ "sys-kernel-config.mount" ];
       #also = [ "targetcli.socket" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.targetcli}/bin/targetclid";
          Restart = "on-failure";
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
