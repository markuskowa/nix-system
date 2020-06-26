{ stdenv, fetchFromGitHub, perl, autoconf, automake
, libtool, flex, libevent, hwloc, munge, zlib
} :

let
  version = "3.1.5";

in stdenv.mkDerivation {
  name = "pmix-${version}";

  src = fetchFromGitHub {
    repo = "pmix";
    owner = "pmix";
    rev = "v${version}";
    sha256 = "0fvfsig20amcigyn4v3gcdxc0jif44vqg37b8zzh0s8jqqj7jz5w";
  };

  nativeBuildInputs = [ perl autoconf automake libtool flex ];

  buildInputs = [ libevent hwloc munge zlib ];

  configureFlags = [
    "--with-libevent=${libevent.dev}"
    "--with-munge=${munge}"
    "--with-hwloc=${hwloc.dev}"
  ];

  preConfigure = ''
    patchShebangs ./autogen.pl
    patchShebangs ./config
    ./autogen.pl
  '';

  enableParallelBuilding = true;


  meta = with stdenv.lib; {
    description = "";
    homepage = https://;
    license = with licenses; gpl2;
    platforms = platforms.linux;
  };
}

