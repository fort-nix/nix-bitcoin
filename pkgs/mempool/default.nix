{ pkgs, lib, fetchFromGitHub, fetchurl, makeWrapper, rsync }:
rec {
  nodejs = pkgs.nodejs-16_x;
  nodejsRuntime = pkgs.nodejs-slim-16_x;

  src = fetchFromGitHub {
    owner = "mempool";
    repo = "mempool";
    rev = "v2.3.1";
    hash = "sha256-l7wdbNDi7A8o2nBg3V7FR+TAd0PIZBhIw44k+9OAaX4=";
  };

  # node2nix requires that the backend and frontend are available as distinct node
  # packages
  srcBackend = pkgs.runCommand "mempool-backend" {} ''
    cp -r --no-preserve=mode ${src}/backend $out
    cd $out
    patch -p2 <${./fix-config-path.patch}
  '';
  srcFrontend = pkgs.runCommand "mempool-frontend" {} ''
    cp -r ${src}/frontend $out
  '';

  nodeEnv = import "${toString pkgs.path}/pkgs/development/node-packages/node-env.nix" {
    inherit (pkgs) stdenv lib python2 runCommand writeTextFile writeShellScript;
    inherit pkgs nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };

  nodePkgs = file: import file {
    inherit (pkgs) fetchurl nix-gitignore stdenv lib fetchgit;
    inherit nodeEnv;
  };
  backendPkgs = nodePkgs ./node-packages-backend.nix;
  frontendPkgs = nodePkgs ./node-packages-frontend.nix;

  mempool-backend = nodeEnv.buildNodePackage (backendPkgs.args // {
    src = srcBackend;

    nativeBuildInputs = (backendPkgs.args.nativeBuildInputs or []) ++ [
      makeWrapper
    ];

    postInstall = ''
      npm run build

      # Remove unneeded src and cache files
      rm -r src cache .[!.]*

      makeWrapper ${nodejsRuntime}/bin/node $out/bin/mempool-backend \
        --add-flags $out/lib/node_modules/mempool-backend/dist/index.js
    '';

    inherit meta;

    passthru.workaround = backend-workaround;
  });

  backend-workaround = mempool-backend.overrideAttrs (old: {
    postInstall = old.postInstall + ''
      # See ./README.md
      cp mempool-config.sample.json mempool-config.json
      mkdir -p ../.git/refs/heads
      echo 0000000000000000000000000000000000000000 > ../.git/refs/heads/master

      makeWrapper ${nodejsRuntime}/bin/node $out/bin/mempool-backend \
        --add-flags $out/lib/node_modules/mempool-backend/dist/index.js \
        --run "cd $out/lib/node_modules/mempool-backend"
    '';
  });

  mempool-frontend =
    import ./frontend.nix srcFrontend nodeEnv frontendPkgs nodejs meta fetchurl rsync;

  meta = with lib; {
    description = "Bitcoin blockchain and mempool explorer";
    homepage = "https://github.com/mempool/mempool/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
}
