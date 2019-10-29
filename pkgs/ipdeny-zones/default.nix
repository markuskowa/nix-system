{ stdenvNoCC, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20191028";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "1slzyva4qhcqgnkky5wgdx1sdr6d4f0k9hikrikzs9sbbqrg4cvi";
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

