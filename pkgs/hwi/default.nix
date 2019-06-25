{ stdenv, fetchurl, fetchFromGitHub, python35 }:

with stdenv.lib;
with python35.pkgs;

let
  buildInputs = [ mnemonic ecdsa typing-extensions hidapi libusb1 pyaes ];
in
buildPythonPackage rec {
  pname = "hwi";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "HWI";
    rev = version;
    sha256 = "0m3p72r8ghzwwsmc7y0dzxn0wzaplqqq1q0cd327fnnljddp5b10";
  };

  # TODO: enable tests
  doCheck = false;

  inherit buildInputs;
  propagatedBuildInputs = buildInputs;

  meta = with lib; {
    homepage = https://github.com/bitcoin-core/hwi;
  };
}
