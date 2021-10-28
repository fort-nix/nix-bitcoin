{ lib, buildPythonPackage, fetchPypi, python
, attrs, enum34, hyperlink, incremental, six, twisted, typing, tubes, werkzeug, zope_interface
, hypothesis, treq
}:

buildPythonPackage rec {
  pname = "klein";
  version = "20.6.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-ZYS5zf9JWbnc7pWhwcIAEPUhoqEsT/PN2LkDqbDpk/Y=";
  };

  propagatedBuildInputs = [ attrs enum34 hyperlink incremental six twisted typing tubes werkzeug zope_interface ];

  checkInputs = [ hypothesis treq ];

  checkPhase = ''
    ${python.interpreter} -m twisted.trial -j $NIX_BUILD_CORES klein
  '';

  meta = with lib; {
    description = "Klein Web Micro-Framework";
    homepage    = "https://github.com/twisted/klein";
    license     = licenses.mit;
    maintainers = with maintainers; [ exarkun ];
  };
}
