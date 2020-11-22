{ stdenv, cmake, fetchFromGitHub } :

stdenv.mkDerivation rec {
  pname = "target-isns";
  version = "0.6.8";

  src = fetchFromGitHub {
    owner = "open-iscsi";
    repo = pname;
    rev = "v${version}";
    sha256 = "1b6jjalvvkkjyjbg1pcgk8vmvc6xzzksyjnh2pfi45bbpya4zxim";
  };

  patches = [ ./install_prefix_path.patch ];

  nativeBuildInputs = [ cmake ];


}
