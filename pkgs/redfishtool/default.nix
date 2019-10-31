{ python3Packages, lib, fetchFromGitHub } :

python3Packages.buildPythonApplication rec {
  pname = "redfishtool";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "DMTF";
    repo = "Redfishtool";
    rev = version;
    sha256 = "1zdpalz1zvjqyhbhdmdvvcag3jwm43hsg1vhnlas2827yd80bx0c";
  };

  propagatedBuildInputs = [ python3Packages.requests ];

  meta = with lib; {
    description = "RESTful API for Data Center Hardware Management";
    maintainters = [ maintainers.markuskowa ];
    license = licenses.bsd3;
    homepage = "https://github.com/DMTF/Redfishtool";
  };
}

