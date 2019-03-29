let
  overlay = builtins.fetchGit {
     url = "https://github.com/mozilla/nixpkgs-mozilla";
     ref = "master";
     rev = "e37160aaf4de5c4968378e7ce6fe5212f4be239f";
   };
  defaultPkgs = import <nixpkgs> {overlays = [ (import overlay) ]; };
  defaultRust = (defaultPkgs.rustChannelOf { date = "2019-03-05"; channel = "nightly"; }).rust;
  defaultCargo = (defaultPkgs.rustChannelOf { date = "2019-03-05"; channel = "nightly"; }).cargo;
  defaultBuildRustPackage = defaultPkgs.callPackage (import <nixpkgs/pkgs/build-support/rust>) {
    rust = {
      rustc = defaultRust;
      cargo = defaultCargo;
    };
  };

in { pkgs ? defaultPkgs, rust ? defaultRust, buildRustPackage ? defaultBuildRustPackage }:
pkgs.lib.flip pkgs.callPackage { inherit buildRustPackage; } (
  { lib, buildRustPackage, fetchFromGitHub, llvmPackages, clang }:

  let
    version = "0.4.3";

  in buildRustPackage {
    name = "electrs-${version}";

    src = fetchFromGitHub {
      owner = "romanz";
      repo = "electrs";
      rev = "5ab3b4648769bf4a421d48fb29c93ef048db7dbf";
      sha256 = "1xjjs1j4wm8pv7h0gr7i8xi2j78ss3haai4hyaiavwph8kk5n0ch";
    };

    cargoSha256 = "0a80i77s3r4nivrrxndadzgxcpnyamrw7xqrrlz1ylwyjz00xcnf";

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
