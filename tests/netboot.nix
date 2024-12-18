{lib, pkgs, ... } :

let
  handleTest = test: (import "${pkgs.path}/nixos/tests/make-test-python.nix") test {};

  # Boot server IP
  ipServer = "192.168.1.1";

  makeTest = type: client: handleTest ({
    name = "${type} boot";

    nodes = {
      inherit client;

      bootServer = { pkgs, modulesPath, config, nodes, ... } :
      {
        imports = [ ../modules/kea.nix ];

        virtualisation.memorySize = 2048;

        networking.firewall = {
          allowedTCPPorts = [ 80 ];
          allowedUDPPorts = [ 69 ];
        };

        services.atftpd = {
          enable = (lib.substring 0 3 type) == "pxe";
          root = "/srv";
        };

        services.httpd = {
          enable = true;
          virtualHosts.boot = {
            documentRoot = config.services.atftpd.root;
          };
        };

        services.kea-simple = {
          enable = true;

          interfaces = [ "eth1" ];

          subnets.eth1 = {
            id = 1;
            subnet = "192.168.1.0/24";
            pools = [ "192.168.1.10 - 192.168.1.20" ];
          };

          netboot = {
            enable = true;
            server = ipServer;

            pxeBios = (type == "pxe-bios");
            pxeUefi = (type == "pxe-uefi");
            httpUefi = (type == "uri-uefi") || (type == "http-uefi");
            ipxe.srvDirectory = config.services.atftpd.root;

            netbootImage.config = { modulesPath, ... }: {
              imports = [
                (modulesPath + "/installer/netboot/netboot-minimal.nix")
                (modulesPath + "/testing/test-instrumentation.nix")
              ];
            };
          };
        };
      };
    };

    testScript = ''
      bootServer.wait_for_unit("kea-dhcp4-server.service")
      bootServer.wait_for_file("/srv/netboot.ipxe")

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
