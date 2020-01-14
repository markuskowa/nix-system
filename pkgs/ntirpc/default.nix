{ stdenv, fetchFromGitHub, cmake
, krb5, liburcu
, libtirpc
} :

stdenv.mkDerivation rec {
  pname = "ntirpc";
  version = "3.2";

  src = fetchFromGitHub {
    owner = "nfs-ganesha";
    repo = "ntirpc";
    rev = "v${version}";
    sha256 = "1m071bwcxmpyj5kwwrk5qhsajhz3fzrpapgrc2ajjc1hw9kx9xxa";
  };

  postPatch = ''
    substituteInPlace ntirpc/netconfig.h --replace "/etc/netconfig" "$out/etc/netconfig"
  '';

  nativeBuildInputs = [ cmake ];
  buildInputs = [ krb5 liburcu ];

  postInstall = ''
    mkdir -p $out/etc

    # library needs a netconfig to run
    # steal the file from libtirpc
    cp ${libtirpc}/etc/netconfig $out/etc/
  '';

  meta = with stdenv.lib; {
    description = "Transport-independent RPC (TI-RPC)";
    homepage = "https://github.com/nfs-ganesha/ntirpc";
    maintainers = [ maintainers.markuskowa ];
    platforms = platforms.linux;
    license = licenses.bsd3;
  };
}
