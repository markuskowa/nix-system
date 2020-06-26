self: super:

let
  callPackage = super.callPackage;

in {
  nfs-ganesha = callPackage ./pkgs/nfs-ganesha {};

  ntirpc = callPackage ./pkgs/ntirpc {};

  ipdeny-zones = callPackage ./pkgs/ipdeny-zones {};

  pmix = callPackage ./pkgs/pmix {};

  openmpi = super.openmpi.overrideAttrs ( x: {
    buildInputs = x.buildInputs ++ [ self.pmix ];
    configureFlags = x.configureFlags ++ [
      #"--with-ompi-pmix-rte"
      #"--disable-oshmem"
      "--with-pmix=${self.pmix}"
      "--with-pmix-libdir=${self.pmix}/lib"
    ];
  });

  slurm = super.slurm.overrideAttrs ( x: {
    buildInputs = x.buildInputs ++ [ self.pmix ];
    nativeBuildInputs = x.nativeBuildInputs ++ [ self.installShellFiles ];
    configureFlags = x.configureFlags ++ [
      "--with-pmix=${self.pmix}"
    ];
    patches = [
      # Required to pick up the right dlopen path
      ./patches/slurm-pmix.patch
      # Account for long nix store paths in commandline string
      ./patches/userenv-maxpath-length.patch
    ];

    postInstall = x.postInstall + ''
      installShellCompletion --bash contribs/slurm_completion_help/slurm_completion.sh
    '';
  });

  redfishtool = callPackage ./pkgs/redfishtool {};
}

