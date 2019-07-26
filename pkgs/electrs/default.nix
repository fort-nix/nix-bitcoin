{ pkgs }:

with pkgs;
rustPlatform.buildRustPackage rec {
    name = "electrs-${version}";
    version = "0.7.0";

    src = fetchFromGitHub {
      owner = "romanz";
      repo = "electrs";
      rev = "dc92454c9d8d681ebf50cca98189526e6580a2ee";
      sha256 = "1hzkpp65x783psfcm29l6vcbz0wgn0dz8n3cchfhd3ldmrjgivgs";
    };

    cargoSha256 = "0xgah4c5isii34z299qwm7gpp3y8n2r4qmmzy1d0c3x7c3fvvk57";

    LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
    buildInputs = [ clang ];

    meta = with lib; {
      description = "An efficient re-implementation of Electrum Server in Rust";
      homepage = https://github.com/romanz/electrs;
      maintainers = with maintainers; [ tailhook ];
      platforms = platforms.all;
    };
  }
