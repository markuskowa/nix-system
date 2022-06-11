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
    ./moosefs-cgiserv.nix
    ./nfs-ganesha.nix
    ./inituser.nix
    ./banner.nix
    ./networkmap.nix
    ./tmpfsroot.nix
    ./zfs-attrs.nix
    ./slurm.nix
  ];

  disabledModules = [ "services/computing/slurm/slurm.nix" ];
  nixpkgs.overlays = [ (import ../default.nix) ];
}
