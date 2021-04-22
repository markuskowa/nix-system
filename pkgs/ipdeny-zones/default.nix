{ stdenvNoCC, lib, fetchFromGitHub } :

stdenvNoCC.mkDerivation rec {
  pname = "ipdeny";
  version = "20210422";

  src = fetchFromGitHub {
    owner = "markuskowa";
    repo = "ipdeny-zones";
    rev = version;
    sha256 = "0qcf5cap3y4ys8mnkfyasmhs57nj8cwma326zws5ixx965jf11xl";
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

