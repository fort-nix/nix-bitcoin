{ lib, stdenv, fetchFromGitHub, cmake }:

let
  ftxui = fetchFromGitHub {
    owner = "ArthurSonzogni";
    repo = "FTXUI";
    rev = "v5.0.0";
    hash = "sha256-IF6G4wwQDksjK8nJxxAnxuCw2z2qvggCmRJ2rbg00+E=";
  };

  catch2 = fetchFromGitHub {
    owner = "catchorg";
    repo = "Catch2";
    rev = "v3.7.1";
    hash = "sha256-Zt53Qtry99RAheeh7V24Csg/aMW25DT/3CN/h+BaeoM=";
  };
in stdenv.mkDerivation {
  pname = "bitcoin-tui";
  version = "0.8.1-unstable-2026-03-27";

  src = fetchFromGitHub {
    owner = "janb84";
    repo = "bitcoin-tui";
    rev = "49d97039d4d1cb18699973edfc73d4790ed817ea";
    hash = "sha256-kbBesK0aPrpERktmyf4R7tqWyDmHZtwoAzdHt3vSVbM=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_SOURCE_DIR_FTXUI=${ftxui}"
    "-DFETCHCONTENT_SOURCE_DIR_CATCH2=${catch2}"
  ];

  installPhase = ''
    install -Dm755 bin/bitcoin-tui $out/bin/bitcoin-tui
  '';

  meta = with lib; {
    description = "Terminal UI dashboard for Bitcoin Core nodes";
    homepage = "https://github.com/janb84/bitcoin-tui";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
