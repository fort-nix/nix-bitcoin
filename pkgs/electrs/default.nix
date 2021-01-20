{ lib, rustPlatform, llvmPackages, fetchurl, pkgs }:
rustPlatform.buildRustPackage rec {
  pname = "electrs";
  version = "0.8.7";

  src = fetchurl {
    url = "https://github.com/romanz/electrs/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "f967f322ebf86dd32d291716fa8e8b155da4b35d003b116b4e7007054d6b515e";
  };

  # Needed for librocksdb-sys
  nativeBuildInputs = [ llvmPackages.clang ];
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  cargoSha256 = "12ypx0rkpbjl4awzx8ga30qhiqqd56a24q4jwlxxnfpw9ks1z252";

  meta = with lib; {
    description = "An efficient Electrum Server in Rust";
    homepage = "https://github.com/romanz/electrs";
    license = licenses.mit;
    maintainers = with maintainers; [ earvstedt ];
  };
}
