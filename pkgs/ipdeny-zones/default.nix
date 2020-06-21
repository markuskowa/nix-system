{ stdenvNoCC, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20200621";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "0pd0glanazij12zkbn3z46kr6yzk2kbifck2ys4y2h6r8vcxl3fq";
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

