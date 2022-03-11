{ lib, stdenv, fetchFromGitHub
, autoconf, automake, libtool, makeWrapper
, jq, parallel, squashfsTools
}:

stdenv.mkDerivation rec {
  pname = "enroot";
  version = "3.4.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "enroot";
    rev = "v${version}";
    sha256 = "0qignd8rb9wq3h391cybcy7x389dl8jx21brpm19jbm31yij7c77";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    makeWrapper
  ];

  makeFlags = [ "prefix=${placeholder "out"}"];

  postInstall = ''
    wrapProgram $out/bin/enroot --prefix PATH ":" "${jq}/bin:${parallel}/bin:${squashfsTools}/bin"
  '';

  meta = with lib; {
    description = "Turn traditional container/OS images into unprivileged sandboxes";
    homepage = "https://github.com/nvidia/enroot";
    license = licenses.asl20;
    maintainers = [ maintainers.markuskowa ];
    platforms = platforms.linux;
  };
}
