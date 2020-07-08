{ lib, rustPlatform, llvmPackages, fetchurl, pkgs }:
rustPlatform.buildRustPackage rec {
  pname = "electrs";
  version = "0.8.5";

  src = fetchurl {
    url = "https://github.com/romanz/electrs/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "651663f68ead632d806980c1915e4b963dcccfbb674c794a7c5d9b7cc4dfecbf";
  };

  # Needed for librocksdb-sys
  nativeBuildInputs = [ llvmPackages.clang ];
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  cargoSha256 = if builtins.pathExists "${pkgs.path}/pkgs/build-support/rust/fetchcargo.nix" then
    # nixpkgs ≤ 20.03
    "0clxam7i5yxiqsqxwzdq6z7j7c82rj5zyk186vhvzwh6hzfrv7zm"
  else
    # for recent nixpkgs with cargo-native vendoring (introduced in nixpkgs PR #69274)
    "0kpv2y22wi42ymcwbqr1cw6npb0ca11hi3dhhhdj1al8kzdgi70w";

  meta = with lib; {
    description = "An efficient Electrum Server in Rust";
    homepage = "https://github.com/romanz/electrs";
    license = licenses.mit;
    maintainers = with maintainers; [ earvstedt ];
  };
}
