{ ... } :

{
  # Import all the modules from the overlay
  imports = [
    ./beegfs.nix
    ./countryfw.nix
    ./infiniband.nix
    ./iscsid.nix
    ./iscsiBoot.nix
    ./iscsiTarget.nix
    ./isns.nix
    ./macsec.nix
    ./hostapd-radius.nix
    ./hostapd-wired.nix
    ./supplicant.nix
    ./moosefs-cgiserv.nix
    ./nfs-ganesha.nix
    ./inituser.nix
    ./banner.nix
    ./networkmap.nix
    ./tmpfsroot.nix
    ./vxlan.nix
    ./zfs-attrs.nix
    ./zenoh.nix
  ];

  nixpkgs.overlays = [ (import ../default.nix) ];
  nixpkgs.config.allowUnfree = true;
}
