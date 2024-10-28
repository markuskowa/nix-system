{ stdenvNoCC, lib, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20241023";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    hash = "sha256-vc9OV+v7stQ55H4SiKXWVcqKpLn1u6pW1i0O4A04ii8=";
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

