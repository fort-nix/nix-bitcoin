{ version, src, lib, buildPythonPackage, fetchurl, txtorcon, cryptography, pyopenssl, libnacl, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketdaemon";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmdaemon";

  propagatedBuildInputs = [ txtorcon cryptography pyopenssl libnacl joinmarketbase ];

  # libnacl 1.8.0 is not on github
  # cryptography 41.0.3 already in ../specific-versions
  patchPhase = ''
    substituteInPlace setup.py \
      --replace "'libnacl==1.8.0'" "'libnacl==1.7.2'"
    substituteInPlace setup.py \
      --replace "'cryptography==41.0.2" "'cryptography==41.0.3"
  '';

  meta = with lib; {
    description = "Client library for Bitcoin coinjoins";
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
