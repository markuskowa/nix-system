{ lib, stdenv, fetchFromGitLab, kmod, kernel } :

let
  common = import ./common.nix fetchFromGitLab;

in stdenv.mkDerivation ({
  patches = [
    # Fix paths in cmake files
    ./module-makefile.patch
  ];

  postPatch = ''
     patchShebangs  client_module/build/feature-detect.sh
  '';

  nativeBuildInputs = [
    kmod
  ];

  preBuild = ''
    cd client_module/build
    export makeFlagsArray=(
        DESTDIR=$out
        KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
        )
  '';

  meta = with lib; {
    description = "Hardware-independent POSIX parallel file system";
    homepage = "https://www.beegfs.io";
    maintainers = [ maintainers.markuskowa ];
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
} // common)

