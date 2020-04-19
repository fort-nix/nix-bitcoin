let
  fetch = { rev, sha256 }:
    builtins.fetchurl {
      url = "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
rec {
  # To update, run ../helper/wot-update-channels
  nixpkgs-packed = fetch {
    rev = "1d8a149ccea76b6fed87d2506391c2905a4c0440";
    sha256 = "60e0a600776e0548e5540d83bffb8c958794a2057d5b0f7362113344bffbe0a7";
  };
  nixpkgs-unstable-packed = fetch {
    rev = "a7971df962fd026843f1707c237294341920757e";
    sha256 = "a5c40ca1a4a595cfea3596045c6da2db9556e3dd680e92123e45f848c36a578e";
  };

  nixpkgs = (import <nixpkgs> {}).runCommand "nixpkgs-src" {} ''
    mkdir $out; tar xf "${toString nixpkgs-packed }" --strip 1 -C $out
  '';
  nixpkgs-unstable = (import <nixpkgs> {}).runCommand "nixpkgs-unstable-src" {} ''
    mkdir $out; tar xf "${toString nixpkgs-unstable-packed }" --strip 1 -C $out
  '';
}
