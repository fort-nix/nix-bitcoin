{ lib, rustPlatform, llvmPackages, fetchurl, pkgs }:
rustPlatform.buildRustPackage rec {
  pname = "electrs";
  version = "0.8.3";

  src = fetchurl {
    url = "https://github.com/romanz/electrs/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "6a00226907a0c36b10884e7dd9f87eb58123f089977a752b917d166af072ea3d";
  };

  # Needed for librocksdb-sys
  nativeBuildInputs = [ llvmPackages.clang ];
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  cargoSha256 = if builtins.pathExists "${pkgs.path}/pkgs/build-support/rust/fetchcargo.nix" then
    # nixpkgs ≤ 20.03
    "19qs8if8fmygv6j74s6iwzm534fybwasjvmzdqcl996xhg75w6gi"
  else
    # for recent nixpkgs with cargo-native vendoring (introduced in nixpkgs PR #69274)
    "1x88zj7p4i7pfb25ch1a54sawgimq16bfcsz1nmzycc8nbwbf493";

  meta = with lib; {
    description = "An efficient Electrum Server in Rust";
    homepage = "https://github.com/romanz/electrs";
    license = licenses.mit;
    maintainers = with maintainers; [ earvstedt ];
  };
}
