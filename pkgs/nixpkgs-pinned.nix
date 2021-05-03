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
    rev = "dc326c78a93862efb30a76216f527a56496e6284";
    sha256 = "094zb1p5i5f2nlxny3dc814jvs90nimdj6wwd80495hgs9z76wgp";
  };
  nixpkgs-unstable = fetch {
    rev = "4518794ee53d109d551c210a6d195b79e9995a90";
    sha256 = "1h86bqrkiydn5nwpndg8k5apdjxff5qigbrrwfam3893vgb7hws2";
  };
}
