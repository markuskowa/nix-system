{lib, pkgs, ... } :

let
  handleTest = test: (import "${pkgs.path}/nixos/tests/make-test-python.nix") test {};
  ipServer = "192.168.1.1";

  makeTest = type: client: handleTest ({
    name = "${type} boot";

    nodes = {
      inherit client;

      bootServer = { pkgs, modulesPath, nodes, ... } : let

        configuration = {
          imports = [
            (modulesPath + "/installer/netboot/netboot-minimal.nix")
            (modulesPath + "/testing/test-instrumentation.nix")
          ];
        };

        sys = import "${pkgs.path}/nixos" {
          inherit configuration;
        };

        # Provision images
        setup-boot = pkgs.writeScriptBin "setup-boot" ''
          cp ${pkgs.ipxe}/ipxe.efi /srv
          cp ${pkgs.ipxe}/undionly.kpxe /srv
          cp ${sys.config.system.build.netbootRamdisk}/initrd /srv
          cp ${sys.config.system.build.kernel}/bzImage /srv

          cat > /srv/netboot.ipxe << EOF
          #!ipxe
          dhcp net1
          initrd http://${ipServer}/initrd
          kernel http://${ipServer}/bzImage init=${sys.config.system.build.toplevel}/init ${toString sys.config.boot.kernelParams}
          boot
          EOF
        '';

      in {
        virtualisation.memorySize = 2048;

        networking.firewall = {
          allowedTCPPorts = [ 80 ];
          allowedUDPPorts = [ 69 ];
        };

        services.atftpd = {
          enable = true;
          root = "/srv";
        };

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
                severity = "INFO"; # Set to DEBUG for debugging classes
                debuglevel = 55;
              }];

              valid-lifetime = 3600;

              lease-database = {
                name = "/var/lib/kea/dhcp4.leases";
                persist = true;
                type = "memfile";
              };

              client-classes = [
                { # Serve iPXE script (77 = user class)
                  name = "ipxe";
                  test = "substring(option[77].hex,0,4) == 'iPXE'";
                  boot-file-name = "http://${ipServer}/netboot.ipxe";
                } ]
                ++ lib.optional (type == "http-uefi")
                { # Serve via HTTP (60 = "vendor-class-identifier)
                  name = "http-uefi";
                  test = "substring(option[60].hex, 0, 10 ) == 'HTTPClient' and not member('ipxe')";
                  option-data = [ { name = "vendor-class-identifier"; data = "HTTPClient"; } ];
                  boot-file-name = "http://${ipServer}/ipxe.efi";
                }
                ++ lib.optional (type == "pxe-uefi")
                {
                  name = "pxe-uefi";
                  test = "substring(option[60].hex, 0, 9 ) == 'PXEClient' and option[client-system].hex == 0x0007 and not member('ipxe')";
                  next-server = ipServer;
                  boot-file-name = "ipxe.efi";
                }
                ++ lib.optional (type == "pxe-bios")
                {
                  name = "pxe-bios";
                  test = "substring(option[60].hex, 0, 9 ) == 'PXEClient' and option[client-system].hex == 0x0000 and not member('ipxe')";
                  next-server = ipServer;
                  boot-file-name = "undionly.kpxe";
                }
                ;

              interfaces-config.interfaces = [ "eth1" ];

              subnet4 = [ {
                id = 1;
                subnet = "192.168.1.0/24";
                interface = "eth1";
                pools = [{ pool = "192.168.1.10 - 192.168.1.20"; }];
              }];
            };
          };
        };
      };
    };

    testScript = ''
      bootServer.wait_for_unit("multi-user.target")

      # Deploy images
      bootServer.succeed("setup-boot")

      client.wait_for_unit("multi-user.target")
      client.succeed("cat /etc/os-release  | grep NixOS")
    '';
    });

in {
  pxeBiosBoot = makeTest "pxe-bios" {
    virtualisation = {
      memorySize = 4096;
      useEFIBoot = false;
      useBootLoader = true;
      qemu.drives = lib.mkVMOverride [];
      qemu.options = [
        # accelerate test by booting directly from network device
        "-device virtio-net-pci,netdev=vlan2,mac=52:54:00:12:02:01,bootindex=1"
        "-netdev vde,id=vlan2,sock=\"$QEMU_VDE_SOCKET_1\""
      ];
    };
  };

  pxeUefiBoot = makeTest "pxe-uefi" {
    virtualisation = {
      memorySize = 4096;
      useEFIBoot = true;
      useBootLoader = true;
      qemu.drives = lib.mkVMOverride [];
      qemu.options = [
        "-device virtio-net-pci,netdev=vlan2,mac=52:54:00:12:02:01,bootindex=1"
        "-netdev vde,id=vlan2,sock=\"$QEMU_VDE_SOCKET_1\""
      ];
    };
  };

  httpUefiBoot = makeTest "http-uefi" ({ pkgs, ... } : {
    virtualisation = {
      memorySize = 4096;
      useEFIBoot = true;
      efi.OVMF = pkgs.OVMF.override { httpSupport = true; };
      useBootLoader = true;
      qemu.drives = lib.mkVMOverride [];
      qemu.options = [
        "-device virtio-net-pci,netdev=vlan2,mac=52:54:00:12:02:01,bootindex=1"
        "-netdev vde,id=vlan2,sock=\"$QEMU_VDE_SOCKET_1\""
      ];
    };
  });

  # Boot directly into iPXE with UEFI URI
  uriUefiBoot = makeTest "uri-uefi" ({ pkgs, ... } :
    let
       ovmf = pkgs.OVMF.override { httpSupport = true; };
       mkEfiVars = pkgs.runCommand "set-http-boot" { } ''
         mkdir $out
         ${pkgs.python3Packages.ovmfvartool}/bin/ovmfvartool generate-blank fw
         ${pkgs.python3Packages.virt-firmware}/bin/virt-fw-vars \
           -i fw -o $out/variables.fd \
           --set-boot-uri "http://${ipServer}/ipxe.efi";
       '';
       efiVars = "${mkEfiVars}/variables.fd";

    in {
      virtualisation = {
        memorySize = 4096;
        useEFIBoot = true;
        useBootLoader = true;
        efi.OVMF = ovmf;
        efi.variables = efiVars;
        efi.keepVariables = false; # otherwise generated vars are dropped.
        qemu.drives = lib.mkVMOverride [];
        qemu.options = [
          "-device virtio-net-pci,netdev=vlan2,mac=52:54:00:12:02:01,bootindex=1"
          "-netdev vde,id=vlan2,sock=\"$QEMU_VDE_SOCKET_1\""
        ];
      };
    });
}
