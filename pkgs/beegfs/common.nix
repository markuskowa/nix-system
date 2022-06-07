fetchFromGitLab:

rec {
  pname = "beegfs";
  version = "7.3.0";

  src = fetchFromGitLab {
    domain = "git.beegfs.io";
    owner = "pub";
    repo = "v7";
    rev = version;
    sha256 = "0michkxncs0lhn7x8iphgf32fjar1jcjcs05jzl9f7j58y06yl0q";
  };

  dontFixCmake = true;
}
