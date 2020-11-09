{ stdenv, fetchFromGitHub, autoreconfHook } :
let
  version = "1.4.2";

in stdenv.mkDerivation {
  name = "nhc-${version}";

  src = fetchFromGitHub {
    owner = "mej";
    repo = "nhc";
    rev = "1.4.2";
    sha256 = "1pig932y1xkq316015c04l7dn53sq8zr9l8slfa7wqbh73g4bs48";
  };

  patches = [ ./paths.patch ];

  postPatch = ''
    patchShebangs ./test
    for i in nhc nhc-wrapper nhc-genconf; do
      substituteInPlace $i \
        --replace 'LIBEXECDIR="/usr/libexec"' "LIBEXECDIR=\"$out/libexec\"" \
        --replace '$CONFDIR/scripts' "$out/etc/nhc/scripts"
    done
  '';

  doCheck = false; # does not work due to /dev access
  checkTarget = "test";

  nativeBuildInputs = [ autoreconfHook ];

  meta = with stdenv.lib; {
    description = "LBNL Node Health Check";
    homepage = "https://github.com/mej/nhc";
    license = licenses.bsd3;
    maintainers = [ maintainers.markuskowa ];
    platforms = platforms.linux;
  };
}

