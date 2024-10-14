{lib, ... } : {
  name = "UEFI HTTP boot";

  nodes = {
    server = { pkgs, modulesPath, nodes, ... } : let

      configuration = {
        imports = [
          (modulesPath + "/installer/netboot/netboot-minimal.nix")
          (modulesPath + "/testing/test-instrumentation.nix")
        ];
      };

      sys = import "${pkgs.path}/nixos" {
        inherit configuration;
      };

      ipServer = "192.168.1.2";

      # Provission images
      setup-boot = pkgs.writeScriptBin "setup-boot" ''
        cp ${pkgs.ipxe}/ipxe.efi /srv
        cp ${sys.config.system.build.netbootRamdisk}/initrd /srv
        cp ${sys.config.system.build.kernel}/bzImage /srv

        cat > /srv/netboot.ipxe << EOF
        #!ipxe
        dhcp net1
        initrd http://${ipServer}/initrd
        kernel http://${ipServer}/bzImage  init=${sys.config.system.build.toplevel}/init ${toString sys.config.boot.kernelParams}
        boot
        EOF
      '';

    in {
      virtualisation.memorySize = 2048;

      networking.firewall.allowedTCPPorts = [ 80 ];
      services.httpd = {
        enable = true;
        virtualHosts.boot = {
          documentRoot = "/srv";
        };
      };

      environment.systemPackages = [ setup-boot ];

      services.kea = {
        ctrl-agent = {
          enable = true;
          settings = {
            http-port = 8000;
            http-host = "127.0.0.1";

            control-sockets = {
               dhcp4 = {
                 socket-type = "unix";
                 socket-name = "/run/kea/socket-dhcp-v4";
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
              output_options = [ { output = "syslog"; }];
              severity = "DEBUG";
              debuglevel = 40;
            }];

            valid-lifetime = 3600;

            lease-database = {
              name = "/var/lib/kea/dhcp4.leases";
              persist = true;
              type = "memfile";
            };

            # Reduce  chatter in logs
            expired-leases-processing.reclaim-timer-wait-time = 1800;

            client-classes = [
              # {
              #   name = "Legacy PXE";
              #   test = "option[client-system].hex == 0x0000";
              #   # next-server = "hosts.files-virtual";
              #   boot-file-name = "undionly.kpxe";
              # }
              # {
              #   name = "PXE-UEFI";
              #   test = "option[client-system].hex == 0x0007 and not member('`')";
              #   # next-server = "192.168.1.2";
              #   boot-file-name = "http://192.168.1.2/ipxe.efi";
              # }
              {
                name = "iPXE";
                test = "substring(option[77].hex,0,4) == 'iPXE'";
                boot-file-name = "http://${ipServer}/netboot.ipxe";
              }
              {
                name = "HTTPClient-UEFI";
                test = "option[93].hex == 0x0010 and not member('iPXE')";
                option-data = [ { name = "vendor-class-identifier"; data = "HTTPClient"; } ];
                boot-file-name = "http://${ipServer}/ipxe.efi";
              }
            ];

            interfaces-config.interfaces = [ "eth1" ];

            subnet4 = [ {
              id = 1;
              subnet = "192.168.1.0/24";
              interface = "eth1";
              pools = [{ pool="192.168.1.10 - 192.168.1.20"; }];
            }];
          };
        };
      };
    };

    client = { pkgs, ...} : {
      virtualisation = {
        memorySize = 4096;

        #
        useEFIBoot = true;
        useBootLoader = true;
        efi.OVMF = pkgs.OVMF.override { httpSupport = true; };
        qemu.drives = lib.mkVMOverride [];
        qemu.options = [
          # accelerate test by
          "-device virtio-net-pci,netdev=vlan2,mac=52:54:00:12:02:01,bootindex=1"
          "-netdev vde,id=vlan2,sock=\"$QEMU_VDE_SOCKET_1\""
        ];
      };
    };
  };

  testScript = ''
    server.wait_for_unit("multi-user.target")

    # Deploy images
    server.succeed("setup-boot")

    client.wait_for_unit("multi-user.target")
    client.succeed("uptime")
  '';
}
