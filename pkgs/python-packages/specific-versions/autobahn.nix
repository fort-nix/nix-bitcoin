# Like nixpkgs revision 8d668463b0883b2e21ba2e2635cd5f9bbc409b18
# but without Python 2 support

{ lib, buildPythonPackage, fetchPypi,
  six, txaio, twisted, zope-interface, cffi,
  mock, pytest, cryptography, pynacl
}:
buildPythonPackage rec {
  pname = "autobahn";
  version = "20.12.3";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    sha256 = "15b8zm7jalwisfwc08szxy3bh2bnn0hd41dbsnswi0lqwbh962j1";
  };

  propagatedBuildInputs = [ six txaio twisted zope-interface cffi cryptography pynacl ];

  checkInputs = [ mock pytest ];
  checkPhase = ''
    runHook preCheck
    USE_TWISTED=true py.test "$out"
    runHook postCheck
  '';

  # Tests do no seem to be compatible yet with pytest 5.1
  # https://github.com/crossbario/autobahn-python/issues/1235
  doCheck = false;

  meta = with lib; {
    description = "WebSocket and WAMP in Python for Twisted and asyncio.";
    homepage    = "https://crossbar.io/autobahn";
    license     = licenses.mit;
    maintainers = with maintainers; [ nand0p ];
  };
}
