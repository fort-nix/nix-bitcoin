{ lib, buildPythonPackage, fetchurl, pyqt5, click }:

buildPythonPackage rec {
  pname = "liquid-swap";
  version = "0.0.1";

  # We're only interested in the cli and not the gui but we need to add pyqt5
  # anyway as a build dependency because liquid-swap's setup.py demands it. See
  # issue https://github.com/Blockstream/liquid-swap/issues/1.
  nativeBuildInputs = [ pyqt5 ];
  propagatedBuildInputs = [ click ];

  src = fetchurl {
    urls = [ "https://github.com/Blockstream/liquid-swap/archive/release_${version}.tar.gz" ];
    sha256 = "c90ba78105469273fb799f412caa754d18bfa310984fa11ffd0091f146cca2ba";
  };
}
