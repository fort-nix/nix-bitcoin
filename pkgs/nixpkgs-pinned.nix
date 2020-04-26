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
    rev = "839cd8d03aa55f067e23a64097fc5b7d7e02f468";
    sha256 = "1w0xklkk9lbwvrx02gng71pyf476h223098692pji5wg5l0sgm02";
  };
  nixpkgs-unstable = fetch {
    rev = "7c2fc1ce23a805f3220d867f528ceb9bd848d2e1";
    sha256 = "1g562hlp5ha11a41daav9bnq86n4nmbm3xzhpzmma8c4jn4k2p8y";
  };
}
