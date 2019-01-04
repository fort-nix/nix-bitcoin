let
  PkgsSource = builtins.fetchGit { url = "https://github.com/nixos/nixpkgs-channels"; ref = "nixos-18.09"; };
  defaultPkgs = import PkgsSource {overlays = [(import (builtins.fetchTarball https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz)) ]; };
  defaultRust = defaultPkgs.latest.rustChannels.nightly.rust;
  defaultCargo = defaultPkgs.latest.rustChannels.nightly.cargo;
  defaultBuildRustPackage = defaultPkgs.callPackage (import "${PkgsSource}/pkgs/build-support/rust") {
    rust = {
      rustc = defaultRust;
      cargo = defaultCargo;
    };
  };

in { pkgs ? defaultPkgs, rust ? defaultRust, buildRustPackage ? defaultBuildRustPackage }:
pkgs.lib.flip pkgs.callPackage { inherit buildRustPackage; } (
  { lib, buildRustPackage, fetchFromGitHub, llvmPackages, clang }:

  let
    version = "0.4.2";

  in buildRustPackage {
    name = "electrs-${version}";

    src = fetchFromGitHub {
      owner = "romanz";
      repo = "electrs";
      rev = "5f2d4289dcb98ef283725b3d12f8733a7b9e832b";
      sha256 = "1lqhrcyd8hdaja5k01a2banvjcbxxcwvb2p7zh05984fpzzs02gr";
    };

    cargoSha256 = "0v0cc62mx728cqfyz3x1bfh2436yiw2hkv58672j2f45cafcgp2h";

    LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
    buildInputs = [ clang ];

    meta = with lib; {
      description = "An efficient re-implementation of Electrum Server in Rust";
      homepage = https://github.com/romanz/electrs;
      maintainers = with maintainers; [ tailhook ];
      platforms = platforms.all;
    };
  }
)


