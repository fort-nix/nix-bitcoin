let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs-channels/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
{
  # To update, run ../helper/fetch-channel REV
  nixpkgs = fetch {
    rev = "27a5ddcf747fb2bb81ea9c63f63f2eb3eec7a2ec";
    sha256 = "1bp11q2marsqj3g2prdrghkhmv483ab5pi078d83xkhkk2jh3h81";
  };
  nixpkgs-unstable = fetch {
    rev = "4cd2cb43fb3a87f48c1e10bb65aee99d8f24cb9d";
    sha256 = "1d6rmq67kdg5gmk94wx2774qw89nvbhy6g1f2lms3c9ph37hways";
  };
}
