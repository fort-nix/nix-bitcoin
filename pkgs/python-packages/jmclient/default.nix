{ version, src, lib, buildPythonPackage, fetchurl, future, configparser, joinmarketbase, mnemonic, argon2_cffi, bencoderpyx, pyaes, joinmarketbitcoin, txtorcon }:

buildPythonPackage rec {
  pname = "joinmarketclient";
  inherit version src;

  postUnpack = "sourceRoot=$sourceRoot/jmclient";

  checkInputs = [ joinmarketbitcoin txtorcon ];

  # configparser may need to be compiled with python_version<"3.2"
  propagatedBuildInputs = [ future configparser joinmarketbase mnemonic argon2_cffi bencoderpyx pyaes ];

  meta = with lib; {
    description = "Client library for Bitcoin coinjoins";
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.gpl3;
  };
}
