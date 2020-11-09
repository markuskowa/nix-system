self: super:

let
  callPackage = super.callPackage;

in {
  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  pmix = callPackage ./pkgs/pmix {};

  nhc = callPackage ./pkgs/nhc {};

  slurmPmix = super.slurm.overrideAttrs ( x: {
    buildInputs = x.buildInputs ++ [ self.pmix ];
    configureFlags = x.configureFlags ++ [
      "--with-pmix=${self.pmix}"
    ];
    patches = [
      # Required to pick up the right dlopen path
      ./patches/slurm-pmix.patch
      # Account for long nix store paths in commandline string
      ./patches/userenv-maxpath-length.patch
    ];
  });

  redfishtool = callPackage ./pkgs/redfishtool {};
}

