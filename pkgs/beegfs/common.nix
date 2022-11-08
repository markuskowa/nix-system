fetchFromGitLab:

rec {
  pname = "beegfs";
  version = "7.3.2";

  src = fetchFromGitLab {
    domain = "git.beegfs.io";
    owner = "pub";
    repo = "v7";
    rev = version;
    sha256 = "sha256-VM82O1Z07qwdoVnHTYXMBzMZLriN39Ahspsg9kHNoV8=";
  };

  dontFixCmake = true;
}
