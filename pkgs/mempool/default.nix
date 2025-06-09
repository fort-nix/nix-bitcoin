{ lib
, stdenvNoCC
, nodejs_22
, nodejs-slim_22
, fetchFromGitHub
, fetchNodeModules
, runCommand
, makeWrapper
, curl
, cacert
, rsync
# for rust-gbt (backend module)
, cargo
, rustc
, rustPlatform
, napi-rs-cli
}:
rec {
  nodejs = nodejs_22;
  nodejsRuntime = nodejs-slim_22;

  version = "3.2.1";

  src = fetchFromGitHub {
    owner = "mempool";
    repo = "mempool";
    tag = "v${version}";
    hash = "sha256-O2XPD1/BXQnzuOP/vMVyRfmFZEgjA85r+PShWne0vqU=";
  };

  nodeModules = {
    frontend = fetchNodeModules {
      inherit src nodejs;
      sourceRoot = "source/frontend";
      hash = "sha256-+jfgsAkDdYvgso8uSHaBj/sQL3fC/ABQWzVTXfdZcU0=";
    };
    backend = fetchNodeModules {
      inherit src nodejs;
      sourceRoot = "source/backend";
      hash = "sha256-y5l2SYZYK9SKSy6g0+mtTWD6JFkkdQHHBboECpEvWZ4=";
    };
  };

  frontendAssets = fetchFiles {
    name = "mempool-frontend-assets";
    hash = "sha256-r6GfOY8Pdh15o2OQMk8syfvWMV6WMCReToAEkQm7tqQ=";
    fetcher = ./frontend-assets-fetch.sh;
  };

  mempool-backend = mkDerivationMempool {
    pname = "mempool-backend";

    patches = [ ./0001-allow-disabling-mining-pool-fetching.patch ];

    buildPhase = ''
      cd backend
      ${sync} --chmod=+w ${nodeModules.backend}/lib/node_modules .
      patchShebangs node_modules

      ${sync} ${mempool-rust-gbt}/ rust-gbt
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
      nodeModules = nodeModules.backend;
    };
  };

  mempool-frontend = mkFrontend {};

  # Argument `config` (type: attrset) defines the mempool frontend config.
  # If `{}`, the default config is used.
  # See here for available options:
  # https://github.com/mempool/mempool/blob/master/frontend/src/app/services/state.service.ts
  # (`interface Env` and `defaultEnv`)
  mkFrontend = config: mkDerivationMempool {
    pname = "mempool-frontend";

    buildPhase = ''
      cd frontend

      ${sync} --chmod=+w ${nodeModules.frontend}/lib/node_modules .
      patchShebangs node_modules

      # sync-assets.js is called during `npm run build` and downloads assets from the
      # internet. Disable this script and instead add the assets manually after building.
      : > sync-assets.js

      ${lib.optionalString (config != {}) ''
        ln -s ${builtins.toFile "mempool-frontend-config" (builtins.toJSON config)} mempool-frontend-config.json
      ''}

      npm run build

      # Add assets that would otherwise be downloaded by sync-assets.js
      ${sync} ${frontendAssets}/ dist/mempool/browser/resources

      runHook postBuild
    '';

    installPhase = ''
      ${sync} dist/mempool/browser/ $out

      runHook postInstall
    '';

    passthru = {
      withConfig = mkFrontend;
      assets = frontendAssets;
      nodeModules = nodeModules.frontend;
    };
  };

  mempool-rust-gbt = stdenvNoCC.mkDerivation rec {
    pname = "mempool-rust-gbt";
    inherit version src meta;

    sourceRoot = "source/rust/gbt";

    nativeBuildInputs = [
      rustPlatform.cargoSetupHook
      cargo
      rustc
      napi-rs-cli
    ];

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      name = "${pname}-${version}";
      inherit sourceRoot;
      hash = "sha256-eox/K3ipjAqNyFt87lZnxaU/okQLF/KIhqXrX86n+qw=";
    };

    buildPhase = ''
      runHook preBuild
      # napi doesn't accept an absolute path as dest dir, so we can't directly write to $out
      napi build --platform --release --strip out
      runHook postBuild
    '';

    installPhase = ''
      mv out $out
      cp package.json $out
    '';

    passthru = { inherit cargoDeps; };
  };

  mempool-nginx-conf = runCommand "mempool-nginx-conf" {} ''
    ${sync} --chmod=u+w ${./nginx-conf}/ $out
    ${sync} ${src}/production/nginx/http-language.conf $out
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
