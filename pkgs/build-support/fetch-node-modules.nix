# This is a modified version of
# https://github.com/NixOS/nixpkgs/pull/128749

{ lib, stdenvNoCC, makeWrapper, nodejs }:

{ src
, hash ? ""
, runScripts ? false
, preferLocalBuild ? true
, npmFlags ? ""
, ...
} @ args:
stdenvNoCC.mkDerivation ({
  inherit src preferLocalBuild;

  name = "${src.name}-node_modules";
  nativeBuildInputs = [
    makeWrapper
    (if args ? nodejs then args.nodejs else nodejs)
  ];

  outputHashMode =  "recursive";

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;

  phases = "unpackPhase patchPhase buildPhase installPhase";

  buildPhase = ''
    runHook preBuild

    if [[ ! -f package.json ]]; then
        echo "Error: file `package.json` doesn't exist"
        exit 1
    fi
    if [[ ! -f package-lock.json ]]; then
        echo "Error: file `package-lock.json` doesn't exist"
        exit 1
    fi

    export SOURCE_DATE_EPOCH=1
    export npm_config_cache=/tmp
    NPM_FLAGS="--omit=dev --omit=optional --no-update-notifier $npmFlags"
    # Scripts may result in non-deterministic behavior.
    # Some packages (e.g., Puppeteer) use postinstall scripts to download extra data.
    if [[ ! $runScripts ]]; then
        NPM_FLAGS+=" --ignore-scripts"
    fi

    echo "Running npm ci $NPM_FLAGS"
    npm ci $NPM_FLAGS

    cp package.json \
       package-lock.json node_modules/
    rm -f node_modules/.package-lock.json

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r node_modules $out/lib

    runHook postInstall
  '';
} // (
  if hash == "" then {
    outputHashAlgo = "sha256";
    outputHash = "";
  } else {
    outputHash = hash;
  }
) // (builtins.removeAttrs args [ "hash" ]))
