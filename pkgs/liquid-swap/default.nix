{ lib, buildPythonPackage, fetchurl, click }:

buildPythonPackage rec {
  pname = "liquid-swap";
  version = "0.0.2";

  propagatedBuildInputs = [ click ];

  src = fetchurl {
    urls = [ "https://github.com/Blockstream/liquid-swap/archive/release_${version}.tar.gz" ];
    sha256 = "9fa920ee7d03d1af8252131cd7d5a825bb66b8ad536403b4f5437ff6c91a68b1";
  };
  # Not sure if this does anything, but it should
  installFlags = [ ".[CLI]" ];
  # The tests unfortunately seem to require the PyQt for the GUI
  doCheck = false;

  meta = with lib; {
    description = "Swap issued assets on the Liquid network using confidential transactions";
    homepage = "https://github.com/Blockstream/liquid-swap";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = platforms.unix;
  };
}
