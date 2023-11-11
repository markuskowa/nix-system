{ lib, stdenv, fetchFromGitHub
, autoconf, automake, libtool, makeWrapper
, jq, parallel, squashfsTools, libmd
}:

stdenv.mkDerivation rec {
  pname = "enroot";
  version = "3.4.1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "enroot";
    rev = "v${version}";
    sha256 = "sha256-lZxzRcyriwwjbQ/DrARCSTo4iY8KmoDJf+pd/ZSLqWM=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    makeWrapper
  ];

  buildInputs = [ libmd ];
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
