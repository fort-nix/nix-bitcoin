{ lib
, buildNpmPackage
, fetchFromGitHub
, makeWrapper
}:

buildNpmPackage rec {
  pname = "jam";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "joinmarket-webui";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-H5g29UJv3+B92m5Fcpa46+81992jKw1Tno2NkGQ7NRM=";
  };

  npmDepsHash = "sha256-/yBcnG6/x3aXlNOSEa/vIU970YoANYDcHWCRJJPCb+U=";
  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ''
    runHook preBuild

    patchShebangs node_modules
    export PATH=$PWD/node_modules/.bin:$PATH
    ./node_modules/.bin/react-scripts build
    mkdir -p $out

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp -r build/* $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "A web interface for JoinMarket focusing on user-friendliness and ease-of-use.";
    homepage = "https://github.com/joinmarket-webui/jam";
    license = licenses.mit;
    mainProgram = "jam";
    maintainers = with maintainers; [ seberm ];
    platforms = platforms.unix;
  };
}
