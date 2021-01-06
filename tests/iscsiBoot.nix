{ pkgs, lib, ... } :

let
  iqnPfx = "iqn.2004-01.org.nixos.san";

  targetInit = pkgs.writeShellScriptBin "targetInit" ''
    targetcli /backstores/block create vol /dev/vdb
    targetcli /iscsi create ${iqnPfx}:server

    targetcli /iscsi/${iqnPfx}:server/tpg1/luns create /backstores/block/vol
    targetcli /iscsi/${iqnPfx}:server/tpg1/acls create ${iqnPfx}:client

    targetcli saveconfig
  '';

in {
  name = "iSCSI-root";

  nodes = {
    server = {
      imports = [ ../modules/overlay.nix ];

      boot.initrd.postDeviceCommands = ''
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L idata /dev/vdb
      '';

      virtualisation.emptyDiskImages = [ 4096 ];

      # use a dedicated interface for iSCSI
      virtualisation.vlans = [ 1 2 ];
      networking.interfaces.eth2 = {
        useDHCP = false;
        ipv4.addresses = lib.mkOverride 0 [{
          address = "192.168.2.1";
          prefixLength = 24;
        }];
      };

      networking.firewall.allowedTCPPorts = [ 3260 ];
      networking.firewall.allowedUDPPorts = [ 67 ];

      services.iscsiTarget.enable = true;

      environment.systemPackages = [
        targetInit
      ];
    };

    client = { pkgs, ... } : {
      imports = [ ../modules/overlay.nix ];

      # use a dedicated interface for iSCSI
      virtualisation.vlans = [ 1 2 ];
      networking.interfaces.eth2 = {
        useDHCP = true;
        ipv4.addresses = lib.mkOverride 0 [{
          address = "192.168.2.2";
          prefixLength = 24;
         };
      };

      # required to configure the network in stage 1
      boot.initrd.kernelModules = [ "virtio_net" "virtio_pci" ];

      # work around: eth2 gets no address from dhcp
      boot.initrd.network.postCommands = ''
        ip addr add 192.168.2.2/24 dev eth2
      '';

      # We only test if the iSCSI login during boot workd
      boot.initrd.iscsi = {
        enable = true;
        initiatorName = "${iqnPfx}:client";
        devices = [{
          target = "${iqnPfx}:server";
          address = "192.168.2.1";
        }];
      };

      environment.systemPackages = [ pkgs.pciutils ];
    };
  };

  testScript = ''
    server.wait_for_unit("multi-user.target")
    server.execute("targetInit")

    client.execute("lsblk -f >&2")
    client.succeed("lsblk -f| grep 'idata'")
  '';
}

