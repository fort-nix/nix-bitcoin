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
    rev = "e6d584f6dd22b587d5cdf5019f5e7dd2be370f61";
    sha256 = "0ysb2017n8g0bpkxy3lsnlf6mcya5gqwggmwdjxlfnj1ilj3lnqz";
  };
  nixpkgs-unstable = fetch {
    rev = "41d921292e922a6cd1aba64259341c244d4c2cc7";
    sha256 = "01iq7phnmyz78qddxsjy6lnpgmzcffxk9h7k69sy61dbjsyy9b4q";
  };
}
