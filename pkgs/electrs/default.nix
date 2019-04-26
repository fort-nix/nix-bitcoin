{ pkgs }:

with pkgs;
rustPlatform.buildRustPackage rec {
    name = "electrs-${version}";
    version = "0.5.0";    

    src = fetchFromGitHub {
      owner = "romanz";
      repo = "electrs";
      rev = "b2b7e1c42acc306df46e97f39d9ab19d2f6f24a8";
      sha256 = "1nz75vc170r6q2hbkyil818y6szrjsas1drxj9vyqls7n5w6whz1";
    };

    cargoSha256 = "1rvhgda4mbwpya8snjqh1z7fjzbabkmh44r4g9ibn83wbd4j32mi";

    LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
    buildInputs = [ clang ];

    meta = with lib; {
      description = "An efficient re-implementation of Electrum Server in Rust";
      homepage = https://github.com/romanz/electrs;
      maintainers = with maintainers; [ tailhook ];
      platforms = platforms.all;
    };
  }

