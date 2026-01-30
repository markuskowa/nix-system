{ stdenvNoCC, lib, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20260130";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    hash = "sha256-xtrY6hMPYsgxq4LKExUcCfO4HuIGz50krVi+VWz9D00=";
  };

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';

  meta = with lib; {
    description = "Lists of IP address ranges for all countries";
    maintainers = [ maintainers.markuskowa ];
    homepage = "https://github.com/markuskowa/ipdeny-zones";
  };
}

