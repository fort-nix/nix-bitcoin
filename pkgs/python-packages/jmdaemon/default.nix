{ version, src, lib, buildPythonPackage, fetchurl, txtorcon, cryptography, pyopenssl, libnacl, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketdaemon";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmdaemon";

  propagatedBuildInputs = [ txtorcon cryptography pyopenssl libnacl joinmarketbase ];

  patchPhase = ''
    substituteInPlace setup.py \
      --replace "'txtorcon==22.0.0'" "'txtorcon==23.5.0'"
    substituteInPlace setup.py \
      --replace "'libnacl==1.8.0'" "'libnacl==2.1.0'"
    substituteInPlace setup.py \
      --replace "'cryptography==41.0.2" "'cryptography==41.0.3"
  '';

  # The unit tests can't be run in a Nix build environment
  doCheck = false;

  pythonImportsCheck = [
    "jmdaemon"
  ];
  meta = with lib; {
    description = "Client library for Bitcoin coinjoins";
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
