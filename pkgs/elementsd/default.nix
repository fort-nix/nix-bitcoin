{ lib, stdenv, fetchurl, pkgconfig, autoreconfHook, openssl, db48, boost, zeromq, rapidcheck
, zlib, miniupnpc, qtbase ? null, qttools ? null, wrapQtAppsHook ? null, utillinux, protobuf, python3, qrencode, libevent
, withGui }:

with lib;
stdenv.mkDerivation rec {
  pname = "elements${optionalString (!withGui) "d"}";
  version = "0.18.1.12";

  src = fetchurl {
    url = "https://github.com/ElementsProject/elements/archive/elements-${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "84a51013596b09c62913649ac90373622185f779446ee7e65b4b258a2876609f";
  };

  nativeBuildInputs =
    [ pkgconfig autoreconfHook ]
    ++ optional withGui wrapQtAppsHook;

  buildInputs = [ openssl db48 boost zlib zeromq
                  miniupnpc protobuf libevent]
                  ++ optionals stdenv.isLinux [ utillinux ]
                  ++ optionals withGui [ qtbase qttools qrencode ];

  configureFlags = [ "--with-boost-libdir=${boost.out}/lib"
                     "--disable-bench"
                   ] ++ optionals (!doCheck) [
                     "--disable-tests"
                     "--disable-gui-tests"
                   ] ++ optionals withGui [
                     "--with-gui=qt5"
                     "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
                   ];

  checkInputs = [ rapidcheck python3 ];

  doCheck = true;

  checkFlags =
    [ "LC_ALL=C.UTF-8" ]
    # QT_PLUGIN_PATH needs to be set when executing QT, which is needed when testing Bitcoin's GUI.
    # See also https://github.com/NixOS/nixpkgs/issues/24256
    ++ optional withGui "QT_PLUGIN_PATH=${qtbase}/${qtbase.qtPluginPrefix}";

  enableParallelBuilding = true;

  meta = {
    description = "Open Source implementation of advanced blockchain features extending the Bitcoin protocol";
    longDescription= ''
      The Elements blockchain platform is a collection of feature experiments and extensions to the
      Bitcoin protocol. This platform enables anyone to build their own businesses or networks
      pegged to Bitcoin as a sidechain or run as a standalone blockchain with arbitrary asset
      tokens.
    '';
    homepage = http://www.github.com/ElementsProject/elements;
    license = licenses.mit;
    # elements needs hexdump to build, which doesn't seem to build on darwin at the moment.
    platforms = platforms.linux;
  };
}
