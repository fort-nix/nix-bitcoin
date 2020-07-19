{ pkgs, stdenv, fetchurl, fetchFromGitHub, python3 }:

with stdenv.lib;

let
  python = python3.override {
    packageOverrides = self: super: {
      # HWI requires mnemonic <0.19 but nixpkgs has a newer version
      mnemonic = self.callPackage ./mnemonic {};
      # HWI requires ecdsa <0.14 but nixpkgs has a newer version
      ecdsa = self.callPackage ./ecdsa {};
      # HWI requires hidapi 0.7.99 but nixpkgs has a newer version
      hidapi = self.callPackage ./hidapi {
        inherit (pkgs) udev libusb1;
      };
    };
  };
in
python.pkgs.buildPythonPackage rec {
  pname = "hwi";
  version = "1.1.2";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "HWI";
    rev = version;
    sha256 = "01xjkv74ksj8m0l6frk03wq82ilzp5gkz4rf7lhi1h6qkb9kb1x0";
  };

  # TODO: enable tests
  doCheck = false;

  propagatedBuildInputs = with python.pkgs; [ mnemonic ecdsa typing-extensions hidapi libusb1 pyaes ];

  meta = with lib; {
    homepage = https://github.com/bitcoin-core/hwi;
  };
}
