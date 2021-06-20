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
    rev = "69f3a9705014ce75b0489404210995fb6f29836e";
    sha256 = "12rspv54fclh4lsry7jxhg6bidbpvzm14f88wbg7rn7ql1bb4rjc";
  };
  nixpkgs-unstable = fetch {
    rev = "33d42ad7cf2769ce6364ed4e52afa8e9d1439d58";
    sha256 = "0l8vvfq0zk3wdrgr5wnfkk02yx389ikxjgvf7lka2c7rh7rbgvsz";
  };
}
