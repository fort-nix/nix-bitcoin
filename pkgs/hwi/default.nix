{ stdenv, fetchurl, fetchFromGitHub, python3 }:

with stdenv.lib;
with python3.pkgs;

let
  buildInputs = [ mnemonic ecdsa typing-extensions hidapi libusb1 pyaes ];
in
buildPythonPackage rec {
  pname = "hwi";
  version = "1.0.3";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "HWI";
    rev = version;
    sha256 = "1xb8w6w6j6vv2ik2bb25y2w6m0gikmh5446jar0frfp6r6das5nn";
  };

  # TODO: enable tests
  doCheck = false;

  inherit buildInputs;
  propagatedBuildInputs = buildInputs;

  meta = with lib; {
    homepage = https://github.com/bitcoin-core/hwi;
  };
}
