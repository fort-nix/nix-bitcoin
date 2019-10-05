{ stdenv, fetchurl, pkgconfig, autoreconfHook, openssl, db48, boost, zeromq, rapidcheck
, zlib, miniupnpc, qtbase ? null, qttools ? null, wrapQtAppsHook ? null, utillinux, protobuf, python3, qrencode, libevent
, withGui }:

with stdenv.lib;
stdenv.mkDerivation rec{
  name = "elements" + (toString (optional (!withGui) "d")) + "-" + version;
  version = "0.18.1.1";

  src = fetchurl {
    urls = [
            "https://github.com/ElementsProject/elements/archive/elements-${version}.tar.gz"
           ];
    sha256 = "1a2eef6a5ba4bd844047175e0ebf965b46b6f3a9e44b56017962c42d56a33a87";
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
                   ]
                     ++ optionals withGui [ "--with-gui=qt5"
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
