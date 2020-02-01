{ stdenvNoCC, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20200201";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "1v6y6a67iwr6rysgrrs8gmaczl55v9y3nxgv2hg660876c4yzxyg";
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

