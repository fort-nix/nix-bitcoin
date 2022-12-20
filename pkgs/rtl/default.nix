{ lib
, stdenvNoCC
, nodejs-16_x
, nodejs-slim-16_x
, fetchNodeModules
, fetchpatch
, fetchurl
, applyPatches
, makeWrapper
}:
let self = stdenvNoCC.mkDerivation {
  pname = "rtl";
  version = "0.13.2";

  src = fetchurl {
    url = "https://github.com/Ride-The-Lightning/RTL/archive/refs/tags/v${self.version}.tar.gz";
    hash = "sha256-7VrLxmE+xPCipx7UOG1mja2pSBrj+swk55afcvBQeDU=";
  };

  passthru = {
    nodejs = nodejs-16_x;
    nodejsRuntime = nodejs-slim-16_x;

    nodeModules = fetchNodeModules {
      inherit (self) src nodejs;
      hash = "sha256-ohS6gVX0M1Ir1QE9SjibbCrBpkXYIv5jV1Bkv0czRw4=";
    };
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  phases = "unpackPhase patchPhase installPhase";

  # `src` already contains the precompiled frontend and backend.
  # Copy all files required for packaging, like in
  # https://github.com/Ride-The-Lightning/RTL/blob/master/dockerfiles/Dockerfile
  installPhase = ''
    dest=$out/lib/node_modules/rtl
    mkdir -p $dest
    cp -r \
      rtl.js \
      package.json \
      frontend \
      backend \
      ${self.nodeModules}/lib/node_modules \
      $dest

    makeWrapper ${self.nodejsRuntime}/bin/node "$out/bin/rtl" \
      --add-flags "$dest/rtl.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A web interface for LND, c-lightning and Eclair";
    homepage = "https://github.com/Ride-The-Lightning/RTL";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
}; in self
