{ pkgs, lib, config, modulesPath, ... } :

let
  inherit (lib)
    mkIf
    mkOption
    mkDefault
    mkEnableOption
    mapAttrsToList
    types
  ;

  cfg = config.services.kea-simple;

  netbootSys = (import (pkgs.path + "/nixos") {
    configuration = cfg.netboot.netbootImage.config;
  }).config;

in {
  options.services.kea-simple = {
    enable = mkEnableOption "kea simple setup";

    interfaces = mkOption {
      description = "List of interfaces to serve.";
      type = with types; listOf str;
    };

    valid-lifetime = mkOption {
      description = "DHCP lease lifetime.";
      type = types.ints.u32;
      default = 3600;
    };

    subnets = mkOption {
      description = "Defintions for subnets";
      type = types.attrsOf (types.submodule ({...} : {
        options = {
          subnet = mkOption {
            description = "Subnet CIDR.";
            type = types.strMatching "([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}";
          };

          id = mkOption {
            description = "Subnet ID for kea.";
            type = types.ints.u16;
          };

          dns = mkOption {
            description = "List of DNS servers";
            type = with types; listOf (strMatching "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$");
            default = [];
          };

          router = mkOption {
            description = "Router for subnet";
            type = with types; nullOr (strMatching "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$");
            default = null;
          };

          mtu = mkOption {
            description = "MTU of subnet";
            type = types.ints.u16;
            default = 1500;
          };

          pools = mkOption {
            description = "List of IP pools";
            type = with types; listOf str;
            default = [];
          };

          reservations = mkOption {
            description = "MAC based reservations for subnet";
            default = [];
            type = types.listOf (types.submodule ({...} : {
              options = {
                hw-address = mkOption {
                  description = "MAC address for reservation";
                  type = with types; nullOr (strMatching "[a-fA-F0-9]{2}:([a-fA-F0-9]{2}:){4}[a-fA-F0-9]{2}");
                  default = null;
                };

                ip-address = mkOption {
                  description = "IP address for reservation";
                  type = types.strMatching "([0-9]{1,3}\.){3}[0-9]{1,3}";
                };

                hostname = mkOption {
                  description = "Assigned hostname";
                  type = with types; nullOr str;
                  default = null;
                };
              };
            }));
          };
        };
      }));
    };

    netboot = {
      enable = mkEnableOption "Netboot features";

      server = mkOption {
        type = types.str;
        description = "IP address of HTTP/TFTP server.";
        default = null;
      };

      urlPath = mkOption {
        description = "Path appended to image boot URLs";
        type = types.str;
        default = "/";
      };

      pxeBios = mkEnableOption "PXE BIOS";
      pxeUefi = mkEnableOption "PXE UEFI";
      httpUefi = mkEnableOption "HTTP UEFI";

      ipxe = {
        enable = mkOption {
          description = "Enable iPXE scripts";
          type = types.bool;
          default = cfg.netboot.enable;
        };

        script = mkOption {
          description = "iPXE script";
          type = types.str;
          default = null;
        };

        srvDirectory = mkOption {
          description = "Target directory for ipxe images, scripts, and kernels";
          type = types.str;
          default = null;
        };

        package = mkOption {
          description = "";
          type = types.package;
          default = pkgs.ipxe;
        };

        xyz = mkOption {
          description = "Enable netboot.xyz entry";
          type = types.bool;
          default = cfg.netboot.ipxe.enable;
        };
      };

      netbootImage = {
        enable = mkOption {
          description = "NixOS netboot installer";
          type = types.bool;
          default = cfg.netboot.enable;
        };

        sshAuthorizedKeys = mkOption {
          type = with types; listOf str;
          default = [];
        };

        config = mkOption {
          description = ''
            A specification of the desired configuration of the , as a NixOS module.
          '';
          type = types.anything;
          default = {...}: {
            users.users.root.openssh.authorizedKeys.keys = cfg.netboot.netbootImage.sshAuthorizedKeys;
            imports = [
              (modulesPath + "/installer/netboot/netboot-minimal.nix")
           ] ;
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.kea = {
      ctrl-agent = {
        enable = true;
        settings = {
          http-port = mkDefault 8000;
          http-host = mkDefault "127.0.0.1";

          control-sockets = {
             dhcp4 = {
               socket-type = "unix";
               socket-name = "/run/kea/socket-dhcp-v4";
             };
             dhcp6 = {
               socket-type = "unix";
               socket-name = "/run/kea/socket-dhcp-v6";
             };
             d2 = {
               socket-type = "unix";
               socket-name = "/run/kea/socket-d2";
             };
          };
        };
      };

      dhcp4 = {
        enable = true;
        settings = {
          control-socket = {
             socket-type = "unix";
             socket-name = "/run/kea/socket-dhcp-v4";
          };

          loggers = [{
            name = "kea-dhcp4";
            severity = "WARN";
          }];

          lease-database = mkDefault {
            name = "/var/lib/kea/dhcp4.leases";
            persist = true;
            type = "memfile";
          };

          valid-lifetime = mkDefault cfg.valid-lifetime;

          interfaces-config.interfaces = cfg.interfaces;

          client-classes = mkIf cfg.netboot.enable (
            lib.optional cfg.netboot.ipxe.enable
            { # Serve iPXE script (77 = user class)
              name = "ipxe";
              test = "substring(option[user-class].hex,0,4) == 'iPXE'";
              boot-file-name = "http://${cfg.netboot.server}${cfg.netboot.urlPath}/netboot.ipxe";
            }
            ++ lib.optional cfg.netboot.httpUefi
            { # Serve via HTTP (60 = "vendor-class-identifier)
              name = "http-uefi";
              test = "substring(option[vendor-class-identifier].hex, 0, 10 ) == 'HTTPClient' and not member('ipxe')";
              option-data = [ { name = "vendor-class-identifier"; data = "HTTPClient"; } ];
              boot-file-name = "http://${cfg.netboot.server}${cfg.netboot.urlPath}/ipxe.efi";
            }
            ++ lib.optional cfg.netboot.pxeUefi
            {
              name = "pxe-uefi";
              test = "substring(option[vendor-class-identifier].hex, 0, 9 ) == 'PXEClient' and option[client-system].hex == 0x0007 and not member('ipxe')";
              next-server = cfg.netboot.server;
              boot-file-name = "ipxe.efi";
            }
            ++ lib.optional cfg.netboot.pxeBios
            {
              name = "pxe-bios";
              test = "substring(option[vendor-class-identifier].hex, 0, 9 ) == 'PXEClient' and option[client-system].hex == 0x0000 and not member('ipxe')";
              next-server = cfg.netboot.server;
              boot-file-name = "undionly.kpxe";
            }
          );

          subnet4 = mapAttrsToList (name: subnet: {
              inherit (subnet) subnet id;

              pools = map (x: { pool = x; }) subnet.pools;

              reservations = map (x: { inherit (x) ip-address; }
                // lib.optionalAttrs (x.hw-address != null) { inherit (x) hw-address; }
                // lib.optionalAttrs (x.hostname != null) { inherit (x) hostname; }
              ) subnet.reservations;

              option-data = [ { name = "interface-mtu"; data = toString subnet.mtu; } ]
                ++ lib.optional (subnet.router != null) { name = "routers"; data = subnet.routers; }
                ++ lib.optional (lib.length subnet.dns > 0) {
                  name = "domain-name-servers";
                  data = lib.concatStringsSep "," subnet.dns;
                };
            }) cfg.subnets;
        };
      };
    };

    # Create scripts
    services.kea-simple.netboot.ipxe.script = mkIf cfg.netboot.ipxe.enable ''
      #!ipxe

      :menu
      menu Please select an option
      ${lib.optionalString cfg.netboot.netbootImage.enable "item nixos NixOS installer"}
      ${lib.optionalString cfg.netboot.ipxe.xyz "item xyz  Netboot XYZ"}
      item local Boot from local disk
      item config iPXE config
      item shell iPXE shell
      choose --default nixos --timeout 2000 target && goto ''${target}

      :error
      echo An error occoured, press any key to return to menu
      prompt
      goto menu

      ${lib.optionalString cfg.netboot.netbootImage.enable ''
      :nixos
      dhcp && echo DHCP succeeded
      initrd http://${cfg.netboot.server}/initrd
      kernel http://${cfg.netboot.server}/bzImage init=${netbootSys.system.build.toplevel}/init ${toString netbootSys.boot.kernelParams}
      boot || goto error
      ''}

      ${lib.optionalString cfg.netboot.ipxe.xyz ''
      :xyz
      chain --autofree https://boot.netboot.xyz || goto error
      ''}

      :local
      echo Booting from local hard drive
      exit 1

      :config
      echo Type "exit" to return to menu
      set menu menu
      config
      goto menu

      :shell
      echo Type "exit" to return to menu
      set menu menu
      shell
      goto menu
    '';

    systemd.services.netboot-deploy = let
        ipxeScript = pkgs.writeText "netboot.ipxe" cfg.netboot.ipxe.script;
        deployScript = pkgs.writeShellScript "deploy-netboot" ''
          if [ -z "$1" ]; then
            printf "Usage: %s <target directory>\n" $(basename $0)
            exit 0
          fi

          targetDir=$1
          ${lib.optionalString (cfg.netboot.pxeUefi || cfg.netboot.httpUefi) "cp ${cfg.netboot.ipxe.package}/ipxe.efi $targetDir"}
          ${lib.optionalString cfg.netboot.pxeBios "cp ${cfg.netboot.ipxe.package}/undionly.kpxe $targetDir"}

          ${lib.optionalString cfg.netboot.ipxe.enable "cp ${ipxeScript} $targetDir/netboot.ipxe"}
          ${lib.optionalString cfg.netboot.netbootImage.enable ''
            cp ${netbootSys.system.build.netbootRamdisk}/initrd $targetDir
            cp ${netbootSys.system.build.kernel}/bzImage $targetDir
          ''}
        '';
      in mkIf cfg.netboot.enable {
        wantedBy = [ "kea-dhcp4-server.service" ];
        before = [ "kea-dhcp4-server.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${deployScript} ${cfg.netboot.ipxe.srvDirectory}";
        };
      };
  };
}
