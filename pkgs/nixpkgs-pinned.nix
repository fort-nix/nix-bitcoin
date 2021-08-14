let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
{
  # To update, run ../helper/fetch-channel REV
  nixpkgs = fetch {
    # nixos-21.05 (2021-08-03)
    rev = "d4590d21006387dcb190c516724cb1e41c0f8fdf";
    sha256 = "17q39hlx1x87xf2rdygyimj8whdbx33nzszf4rxkc6b85wz0l38n";
  };
  nixpkgs-unstable = fetch {
    rev = "16105403bdd843540cbef9c63fc0f16c1c6eaa70";
    sha256 = "0sl6hsxlh14kcs38jcra908nvi5hd8p8hlim3lbra55lz0kd9rcl";
  };
}
