{ lib, stdenv, fetchFromGitHub, which, util-linux
, autoconf, automake, libtool, makeWrapper
, jq, parallel, squashfsTools, libmd, libbsd
}:

stdenv.mkDerivation rec {
  pname = "enroot";
  version = "3.5.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "enroot";
    rev = "v${version}";
    sha256 = "sha256-Sw4kfsb0Gi21At2pU8lt5wIfCih7VZ7Zf9/62xBKKRU=";
    fetchSubmodules = true;
  };

  preBuild = ''
    # enroot somehow can not find the gcc compiler
    # just link to the wrapped gcc
    mkdir -p deps/dist/musl/bin
    ln -s `which gcc` deps/dist/musl/bin/musl-gcc
    ls -l  deps/dist/musl/bin/musl-gcc
  '';

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    makeWrapper
    util-linux
    which
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
