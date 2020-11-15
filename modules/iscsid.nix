{ config, lib, pkgs, ...} :

with lib;

let
  cfg = config.services.iscsid;

  initiatorName = pkgs.writeText "initiatorname.iscsi" ''
    InitiatorName=${cfg.initiatorName}
  '';

in {
  ###### interface

  options = {
    services.iscsid = {
      enable = mkEnableOption "iSCSI daemon";

      config = mkOption {
        type = types.str;
        description = "Contents of config file (iscsid.conf)";
        default = "/etc/iscsi/iscsid.conf";
      };

      secrets = mkOption {
        type = types.str;
        description = "File with secrets for iscsid.conf";
        default = "/dev/null";
      };

      initiatorName = mkOption {
        type = types.str;
        description = "Initiator name.";
        example = "iqn.2004-01.org.nixos.san:initiator";
        default = "iqn.2004-01.org.nixos.san:${config.networking.hostName}";
      };
    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.openiscsi ];


    systemd.services = {
      iscsid = {
        after = [ "network.target" ];
        before = [ "remote-fs-pre.target" ];
        wantedBy = [ "multi-user.target" ];
        #also = [ "iscsid.socket" ];

        preStart = ''
          # compose config file
          mkdir -p /etc/iscsi
          echo "${cfg.config}" > /etc/iscsi/iscsid.conf
          chmod 0600  /etc/iscsi/iscsid.conf
          cat "${cfg.secrets}" >> /etc/iscsi/iscsid.conf
        '';

        serviceConfig = {
          Type = "notify";
          ExecStart = "${pkgs.openiscsi}/bin/iscsid -f -i ${initiatorName}";
          KillMode = "mixed";
          Restart = "on-failure";
        };
      };

      iscsi = {
        wantedBy = [ "remote-fs.target" ];
        before = [ "remote-fs.target" ];
        after = [ "network.target" "network-online.target" "iscsid.service" ];
        requires = [ "iscsid.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.openiscsi}/bin/iscsiadm -m node --loginall=automatic";
          ExecStop = "${pkgs.openiscsi}/bin/iscsiadm -m node --logoutall=automatic";
          SuccessExitStatus=21;
          RemainAfterExit=true;
        };
       };
    };

    systemd.sockets.iscsid = {
      listenStreams = [ "@ISCSIADM_ABSTRACT_NAMESPACE" ];
      wantedBy = [ "sockets.target" ];
    };
  };
}
