{ config, lib, pkgs, ... } :

with lib;

let
  cfg = config.networking.infiniband;

in {
  ###### interface

  options.networking.infiniband = {
    enable = mkEnableOption "IPoIB";
  };

  ###### implementation

  config = mkIf cfg.enable {

    environment.systemPackages = [
      pkgs.rdma-core
    ];

    boot.kernelModules = [ "ib_umad" "ib_ipoib" ];
  };
}
