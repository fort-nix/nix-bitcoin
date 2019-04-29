{ stdenv, fetchurl, fetchFromGitHub, python35 }:

with stdenv.lib;
with python35.pkgs;

let
  buildInputs = [ mnemonic ecdsa typing-extensions hidapi libusb1 pyaes ];
in
buildPythonPackage rec {
  pname = "hwi";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "HWI";
    rev = "4dd56fda3cd9cade8abc482e43e7733ddc8360a9";
    sha256 = "1xy2iq95b8a4cm9k5yzsi8lx1ha0dral3lhshbl1mfm1fi9ch3nk";
  };

  # TODO: enable tests
  doCheck = false;

  inherit buildInputs;
  propagatedBuildInputs = buildInputs;

  meta = with lib; {
    homepage = https://github.com/bitcoin-core/hwi;
  };
}
