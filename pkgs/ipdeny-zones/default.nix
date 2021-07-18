{ stdenvNoCC, lib, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20210622";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "1dw4zrzxbi1sjz2rwyjdw9bl8qx0dk0vvidb0pfyq4shq7rf3111";
  };

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';

  meta = with lib; {
    description = "Lists of IP address ranges for all countries";
    maintainters = [ maintainers.markuskowa ];
    homepage = "https://github.com/markuskowa/ipdeny-zones";
  };
}

