{ stdenvNoCC, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20210315";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "1king2ksgfpv3v9h027hqv3g1rn1xl3adhdlg1pqxj9mir9ikvdi";
  };

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';

  meta = with stdenvNoCC.lib; {
    description = "Lists of IP address ranges for all countries";
    maintainters = [ maintainers.markuskowa ];
    homepage = "https://github.com/markuskowa/ipdeny-zones";
  };
}

