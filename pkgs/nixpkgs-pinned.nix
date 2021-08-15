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
    # nixos-21.05 (2021-08-14)
    rev = "a445f5829889959d65ad65e5c961d5c67e1cd677";
    sha256 = "0zl930jjacdphplw1wv5nlhjk15zvflzzwp53zbh0l8qq01wh7bl";
  };
  nixpkgs-unstable = fetch {
    rev = "4138cbd913fad85073e59007710e3f083d0eb7c6";
    sha256 = "0l7vaa6mnnmxfxzi9i5gd4c4j3cpfh7gjsjsfk6nnj1r05pazf0j";
  };
}
