{ lib
, stdenvNoCC
, nodejs-16_x
, nodejs-slim-16_x
, fetchNodeModules
, fetchurl
, makeWrapper
, rsync
}:
let self = stdenvNoCC.mkDerivation {
  pname = "clightning-rest";
  version = "0.9.0";

  src = fetchurl {
    url = "https://github.com/Ride-The-Lightning/c-lightning-REST/archive/refs/tags/v${self.version}.tar.gz";
    hash = "sha256-1thorV/UivDDH7oqjfm8VTd47LYSGooR2yEoETgBOH4=";
  };

  passthru = {
    nodejs = nodejs-16_x;
    nodejsRuntime = nodejs-slim-16_x;

    nodeModules = fetchNodeModules {
      inherit (self) src nodejs;
      hash = "sha256-rQrAt2BDmNMUCVWxTJN3qoPonKlRWeJ8C4ZvF/gPygk=";
    };
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  phases = "unpackPhase patchPhase installPhase";

  installPhase = ''
    dest=$out/lib/node_modules/clightning-rest
    mkdir -p $dest
    ${rsync}/bin/rsync -a --inplace * ${self.nodeModules}/lib/node_modules \
      --exclude=/{screenshots,'*.Dockerfile'} \
      $dest

    makeWrapper ${self.nodejsRuntime}/bin/node "$out/bin/cl-rest" \
      --add-flags "$dest/cl-rest.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "REST API for C-Lightning";
    homepage = "https://github.com/Ride-The-Lightning/c-lightning-REST";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
}; in self
