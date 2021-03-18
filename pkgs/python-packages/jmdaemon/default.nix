{ version, src, lib, buildPythonPackage, fetchurl, future, txtorcon, cryptography, pyopenssl, libnacl, joinmarketbase }:

buildPythonPackage rec {
  pname = "joinmarketdaemon";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmdaemon";

  postPatch = ''
     substituteInPlace setup.py \
       --replace cryptography==3.3.2 cryptography>=3.3.2
  '';

  propagatedBuildInputs = [ future txtorcon cryptography pyopenssl libnacl joinmarketbase ];

  meta = with lib; {
    description = "Client library for Bitcoin coinjoins";
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
