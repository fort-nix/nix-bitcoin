{ mkDerivation, lib, fetchFromGitHub, pkg-config
, qmake
, qtbase
, rocksdb
, zeromq
}:

mkDerivation rec {
  pname = "fulcrum";
  version = builtins.substring 0 8 src.rev;

  src = fetchFromGitHub {
    owner = "cculianu";
    repo = "Fulcrum";
    rev = "bcccf76f5fa8570d87a7077caddb86ee504fd1d8";
    sha256 = "sha256-5xIG7CjpEz8XCXMLx2MWrEWVHk6dJVvrvE1Jq9Ji4Hw=";
  };

  nativeBuildInputs = [
    pkg-config
    qmake
  ];

  buildInputs = [
    qtbase
    rocksdb
    zeromq
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "A fast SPV server for BCH and BTC";
    homepage = "https://github.com/cculianu/Fulcrum";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ earvstedt ];
  };
}
