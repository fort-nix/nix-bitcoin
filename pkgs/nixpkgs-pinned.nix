let
  fetchNixpkgs = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    };

  fetch = input: let
    inherit (input) locked;
  in fetchNixpkgs {
    inherit (locked) rev;
    sha256 = locked.narHash;
  };

  lockedInputs = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes;
in
{
  nixpkgs = fetch lockedInputs.nixpkgs;
  nixpkgs-unstable = fetch lockedInputs.nixpkgsUnstable;
}
