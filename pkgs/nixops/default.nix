# An updated version of nixops that's compatible with machines running NixOS 19.09.
# 19.09 demands a suitable base image (defined in nixops-vbox/nix/virtualbox.nix) to
# start the virtualbox guest service during system activation.

{ pkgs, stdenv, runCommand, fetchFromGitHub }:

let
  pluginData = {
    aws = {
      owner = "nixos";
      repo = "nixops-aws";
      rev= "v1.0.0";
      sha256 = "1if6spscsgd6ckivgvbqza5fvvn5hbafi1n8q0fw98s3xpz2hjfm";
    };
    hetzner = {
      owner = "nixos";
      repo = "nixops-hetzner";
      rev = "v1.0.0";
      sha256 = "0cxfjpk2daczv3m7q5bsgfvd30qgmm1y7dnvz6nd7s7l7l0gsvas";
    };
    vbox = {
      owner = "nix-community";
      repo = "nixops-vbox";
      rev = "bff6054ce9e7f5f9aa830617577f1a511a461063";
      sha256 = "0j0lbi8rqmw17ji367zh94lvlb062iiyavl4l7m851v40wqr8a5i";
    };
  };

  origSrc = fetchFromGitHub {
    owner = "NixOS";
    repo = "nixops";
    rev = "2434bf26e0bba49441041ffce36dc324f049bc00";
    sha256 = "0ag05pjwwqdw8in49hr8m8bdg31xsgqs1cawcqyh6a5lsys7f6zg";
  };

  src = runCommand "src" {} ''
    cp --no-preserve=mode -r ${origSrc} $out
    cd $out
    patch -p1 < ${./release.nix.patch}
  '';

  nixopsRelease = import "${src}/release.nix" {
    nixpkgs = pkgs.path;
    inherit pluginData;
    p = (p: with p; [ aws hetzner vbox ]);
  };
in
nixopsRelease.build.${builtins.currentSystem}
