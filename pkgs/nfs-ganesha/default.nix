{ stdenv, fetchFromGitHub, cmake, pkgconfig
, krb5, xfsprogs, jemalloc, dbus, libcap
, ntirpc, liburcu, bison, flex, nfs-utils
} :

stdenv.mkDerivation rec {
  pname = "nfs-ganesha";
  version = "3.2";

  src = fetchFromGitHub {
    owner = "nfs-ganesha";
    repo = "nfs-ganesha";
    rev = "V${version}";
    sha256 = "1pxrglnih92pv1ai9iq3ghz9387a3bn9nzfa5wq9wpr7w51lqjhn";
  };

  patches = [ ./sysstatedir.patch ];

  preConfigure = "cd src";

  cmakeFlags = [ "-DUSE_SYSTEM_NTIRPC=ON" ];

  nativeBuildInputs = [ cmake pkgconfig ];
  buildInputs = [
    krb5 xfsprogs jemalloc
    dbus.lib libcap ntirpc liburcu
    bison flex nfs-utils
  ];

  meta = with stdenv.lib; {
    description = "NFS server that runs in user space";
    homepage = "https://github.com/nfs-ganesha/nfs-ganesha/wiki";
    maintainers = [ maintainers.markuskowa ];
    platforms = platforms.linux;
    license = licenses.lgpl3;
  };
}
