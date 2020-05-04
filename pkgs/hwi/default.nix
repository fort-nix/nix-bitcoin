{ stdenv, fetchurl, fetchFromGitHub, python3 }:

with stdenv.lib;

let
  python = python3.override {
    packageOverrides = self: super: {
      # HWI requires mnemonic <0.19 but nixpkgs has a newer version
      mnemonic = self.callPackage ./mnemonic {};
      # HWI requires ecdsa <0.14 but nixpkgs has a newer version
      ecdsa = self.callPackage ./ecdsa {};
    };
  };
in
python.pkgs.buildPythonPackage rec {
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

  propagatedBuildInputs = with python.pkgs; [ mnemonic ecdsa typing-extensions hidapi libusb1 pyaes ];

  meta = with lib; {
    homepage = https://github.com/bitcoin-core/hwi;
  };
}
