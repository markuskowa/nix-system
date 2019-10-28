{ config, pkgs, lib, ... } :

let
  cfg = config.environment.loginBanner;
  banner = pkgs.writeShellScriptBin "banner.sh" "cfg.script";

in {

  options.environment.loginBanner = {
    enable = mkEnableOption "Enable custom login banner text";

    script = mkOption {
      type = types.lines;
      default = ''
        read one two last_ip last_when << EOF
        $(lastlog -u $USER | tail -1)
        EOF
        SYS=`uname -srmo`
        DATE=`date +"%A, %e %B %Y, %R"`
        version="NixOS ${config.system.nixos.codeName} (${config.system.nixos.version})"
        host=`hostname -s`

        echo "`${pkgs.figlet}/bin/figlet -f ${pkgs.figlet}/share/figlet/big.flf $host`

        $DATE
        $version, $SYS"

        Last login $last_when from $last_ip
      '';

      description = ''
        Script that outputs the dynamic login banner content to stdout.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.loginShellInit = mkIf cfg.enable ''
      # disable for user root and non-interactive tools
      if [ `id -u` != 0 ]; then
        if [ "x''${SSH_TTY}" != "x" ]; then
          ${banner}/bin/banner.sh
        fi
      fi
    '';

    services.openssh.extraConfig = ''
      PrintlastLog no
      PrintMotd no
    '';
  };
