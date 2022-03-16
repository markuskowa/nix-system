{ lib, stdenv, fetchFromGitHub
, enroot, slurm
}:

stdenv.mkDerivation rec {
  pname = "pyxis";
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "pyxis";
    rev = "v${version}";
    sha256 = "0s6qwxzwk5p2y5rz8l4icd9hp7sx9fdqcwnvyiz5w7v7aiqzqxza";
    fetchSubmodules = true;
  };

  buildInputs = [
    enroot
    slurm
  ];

  makeFlags = [ "prefix=${placeholder "out"}"];

  meta = with lib; {
    description = "Slurm SPANK pluging for launching containerized jobs";
    homepage = "https://github.com/nvidia/enroot";
    license = licenses.asl20;
    maintainers = [ maintainers.markuskowa ];
    platforms = platforms.linux;
  };
}
