{ lib, stdenv, fetchFromGitLab, cmake, pkg-config
, rdma-core, xfsprogs, curl
} :

let
  common = import ./common.nix fetchFromGitLab;

in stdenv.mkDerivation ({
  patches = [
    # Fix paths in cmake files
    ./cmake-fix.patch
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt --replace \
      "CPACK_PACKAGING_INSTALL_PREFIX \"/\"" \
      "CPACK_PACKAGING_INSTALL_PREFIX \"$out/\""
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    rdma-core
    xfsprogs
    curl
  ];

  cmakeFlags = [
    "-DBEEGFS_VERSION=${common.version}"
  ];


  preBuild = ''
    export makeFlagsArray=(DESTDIR=$out)
  '';

  postInstall = ''
    mkdir -p $out/share/beegfs
    cp ../LICENSE.txt $out/share/beegfs
  '';

  meta = with lib; {
    description = "Hardware-independent POSIX parallel file system";
    homepage = "https://www.beegfs.io";
    maintainers = [ maintainers.markuskowa ];
    license = {
      fullName = "BeeGFS end user licenses agreement";
      url = "https://doc.beegfs.io/latest/license.html";
      free = false;
    };
    platforms = [ "x86_64-linux" ];
  };
} // common)



