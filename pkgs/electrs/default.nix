{ lib, rustPlatform, llvmPackages, fetchurl, pkgs }:
rustPlatform.buildRustPackage rec {
  pname = "electrs";
  version = "0.8.9";

  src = fetchurl {
    url = "https://github.com/romanz/electrs/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "e28367127bca9d5444b1061ba7cbf2636788b1db80977da05cd7ba2182dde2ca";
  };

  # Needed for librocksdb-sys
  nativeBuildInputs = [ llvmPackages.clang ];
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  cargoSha256 = "07bh5mdmi70gy8bmwjzw87d4kc12d5aciiq3slgc07fvhc7nrlmx";

  meta = with lib; {
    description = "An efficient Electrum Server in Rust";
    homepage = "https://github.com/romanz/electrs";
    license = licenses.mit;
    maintainers = with maintainers; [ earvstedt ];
  };
}
