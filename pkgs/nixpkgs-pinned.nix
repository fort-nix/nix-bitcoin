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
    rev = "b103b4bc62085f475d81e61dca85fe03e7eff935";
    sha256 = "1fjb5c80g1vsz9xvii5l6aiga392pbw6dvjky8wmx8xrc5f5g7ja";
  };
  nixpkgs-unstable = fetch {
    rev = "a5cc7d3197705f933d88e97c0c61849219ce76c1";
    sha256 = "0b7y2nv5nj776zh9jwir8fq1qrgcqpaap05qxlxp9qfngw12k6ji";
  };
}
