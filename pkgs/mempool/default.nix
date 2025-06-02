{ lib
, stdenvNoCC
, nodejs-18_x
, nodejs-slim-18_x
, fetchFromGitHub
, fetchNodeModules
, runCommand
, makeWrapper
, curl
, cacert
, rsync
}:
rec {
  nodejs = nodejs-18_x;
  nodejsRuntime = nodejs-slim-18_x;

  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "mempool";
    repo = "mempool";
    tag = "v${version}";
    hash = "sha256-8HmfytxRte3fQ0QKOljUVk9YAuaXhQQWuv3EFNmOgfQ=";
  };

  nodeModules = {
    frontend = fetchNodeModules {
      inherit src nodejs;
      preBuild = "cd frontend";
      hash = "sha256-/Z0xNvob7eMGpzdUWolr47vljpFiIutZpGwd0uYhPWI=";
    };
    backend = fetchNodeModules {
      inherit src nodejs;
      preBuild = "cd backend";
      hash = "sha256-HpzzSTuSRWDWGbctVhTcUA01if/7OTI4xN3DAbAAX+U=";
    };
  };

  frontendAssets = fetchFiles {
    name = "mempool-frontend-assets";
    hash = "sha256-3TmulAfzJJMf0UFhnHEqjAnzc1TNC5DM2XcsU7eyinY=";
    fetcher = ./frontend-assets-fetch.sh;
  };

  mempool-backend = mkDerivationMempool {
    pname = "mempool-backend";

    buildPhase = ''
      cd backend
      ${sync} --chmod=+w ${nodeModules.backend}/lib/node_modules .
      patchShebangs node_modules

      npm run package

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out/lib/mempool-backend
      ${sync} package/ $out/lib/mempool-backend

      makeWrapper ${nodejsRuntime}/bin/node $out/bin/mempool-backend \
        --add-flags $out/lib/mempool-backend/index.js

      runHook postInstall
    '';

    passthru = {
      inherit nodejs nodejsRuntime;
    };
  };

  mempool-frontend = mkDerivationMempool {
    pname = "mempool-frontend";

    buildPhase = ''
      cd frontend

      ${sync} --chmod=+w ${nodeModules.frontend}/lib/node_modules .
      patchShebangs node_modules

      # sync-assets.js is called during `npm run build` and downloads assets from the
      # internet. Disable this script and instead add the assets manually after building.
      : > sync-assets.js

      # If this produces incomplete output (when run in a different build setup),
      # see https://github.com/mempool/mempool/issues/1256
      npm run build

      # Add assets that would otherwise be downloaded by sync-assets.js
      ${sync} ${frontendAssets}/ dist/mempool/browser/resources

      runHook postBuild
    '';

    installPhase = ''
      ${sync} dist/mempool/browser/ $out

      runHook postInstall
    '';

    passthru = { assets = frontendAssets; };
  };

  mempool-nginx-conf = runCommand "mempool-nginx-conf" {} ''
    ${sync} --chmod=u+w ${./nginx-conf}/ $out
    ${sync} ${src}/production/nginx/http-language.conf $out/mempool
  '';

  sync = "${rsync}/bin/rsync -a --inplace";

  mkDerivationMempool = args: stdenvNoCC.mkDerivation ({
    inherit version src meta;

    nativeBuildInputs = [
      makeWrapper
      nodejs
      rsync
    ];

    phases = "unpackPhase patchPhase buildPhase installPhase";
  } // args);

  fetchFiles = { name, hash, fetcher }: stdenvNoCC.mkDerivation {
    inherit name;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = hash;
    nativeBuildInputs = [ curl cacert ];
    buildCommand = ''
      mkdir $out
      cd $out
      ${builtins.readFile fetcher}
    '';
  };

  meta = with lib; {
    description = "Bitcoin blockchain and mempool explorer";
    homepage = "https://github.com/mempool/mempool/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ erikarvstedt ];
    platforms = platforms.unix;
  };
}
