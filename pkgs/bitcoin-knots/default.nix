{ lib
, stdenv
, fetchurl
, pkg-config
, autoreconfHook
, util-linux
, hexdump
, autoSignDarwinBinariesHook ? null
, boost
, libevent
, miniupnpc
, zeromq
, zlib
, withWallet ? true
, db48
, sqlite
, qrencode
, withCui ? true
, python3
, withGui ? false
, qtbase ? null
, qttools ? null
, wrapQtAppsHook ? null
}:

stdenv.mkDerivation rec {
  pname = "bitcoin-knots";
  version = "28.1.knots20250305";

  src = fetchurl {
    url = "https://github.com/bitcoinknots/bitcoin/archive/v28.1.knots20250305.tar.gz";
    sha256 = "sha256-Y7Kd2y/BT+6WoVost1rBBvopMs4rOwBuxDG53GjhQYM=";
  };

  nativeBuildInputs =
    [ pkg-config autoreconfHook util-linux ]
    ++ lib.optional (autoSignDarwinBinariesHook != null && stdenv.isDarwin) autoSignDarwinBinariesHook
    ++ lib.optionals withGui [ qttools wrapQtAppsHook ];

  buildInputs = [
    boost
    libevent
    miniupnpc
    zeromq
    zlib
    qrencode
  ] ++ lib.optionals withWallet [
    db48
    sqlite
  ] ++ lib.optional withCui python3
    ++ lib.optional withGui qtbase
    ++ lib.optional stdenv.isDarwin hexdump;

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-tests"
  ] ++ lib.optionals (!withWallet) [
    "--disable-wallet"
  ] ++ lib.optionals withGui [
    "--with-gui=qt5"
    "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
  ];

  enableParallelBuilding = true;
  doCheck = false;

  meta = with lib; {
    description = "Bitcoin Knots - peer-to-peer network based digital currency (Bitcoin Core derivative)";
    longDescription = ''
      Bitcoin Knots is a derivative of Bitcoin Core with more features and customizations. 
      It is a full node implementation built on the following principles:
      - Non-contentious features
      - Enhanced configuration options
      - Scalability and performance improvements
    '';
    homepage = "https://bitcoinknots.org/";
    downloadPage = "https://github.com/bitcoinknots/bitcoin";
    changelog = "https://bitcoinknots.org/";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ ];
  };
}
