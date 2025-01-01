let
  importModule = module: { lib, ...} : {
    nixpkgs.overlays = [ (import ../default.nix) ];
    nixpkgs.config.allowUnfree = lib.mkDefault true;

    imports = [ module ];
  };

in {
  banner = importModule ./banner.nix;
  countryfw = importModule ./countryfw.nix;
  hostapd = importModule ./hostapd.nix;
  hostapd-radius = importModule ./hostapd-radius.nix;
  hostapd-wired = importModule ./hostapd-wired.nix;
  infiniband = importModule ./infiniband.nix;
  inituser = importModule ./inituser.nix;
  iscsiBoot = importModule ./iscsiBoot.nix;
  iscsid = importModule ./iscsid.nix;
  iscsiTarget = importModule ./iscsiTarget.nix;
  isns = importModule ./isns.nix;
  macsec = importModule ./macsec.nix;
  machine-info = ./machine-info.nix;
  moosefsCgiserv = importModule ./moosefs-cgiserv.nix;
  networkmap = importModule ./networkmap.nix;
  nfs-ganesha = importModule ./nfs-ganesha.nix;
  suplicant = importModule ./supplicant.nix;
  tmpsRoot = importModule ./tmpfsroot.nix;
  vxlan = importModule ./vxlan.nix;
  zfs-attrs = importModule ./zfs-attrs.nix;
}


