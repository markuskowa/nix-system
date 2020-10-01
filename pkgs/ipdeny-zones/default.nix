{ stdenvNoCC, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20201001";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "06lndsfnq66gi9dfz42ry7hz4zx48gijvxcdy149q3nxmak2vzn2";
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

