{ pkgs, lib, config, ...} :

let
  cfg = config.services.tlshd;
  ini = pkgs.formats.ini {};

in {
  options = {
    services.tlshd = {
      enable = lib.mkEnableOption "tlshd";

      settings = lib.mkOption {
        type = ini.type;
        default = {};
        example = lib.literalExample ''
          "authenticate.server" = {
            "x509.truststore" = "/etc/certs/CA.pem";
            "x509.certificate" = "/etc/certs/serverCert.pem";
            "x509.private_key" = "/etc/certs/serverKey.pem";
          };
        '';
      };
    };
  };

  config = {
    systemd.services.tlshd = {
      wantedBy = [ "remote-fs.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getBin pkgs.ktls-utils}/bin/tlshd -c ${ini.generate "tlshd.config" cfg.settings}";
      };
    };
  };
}
