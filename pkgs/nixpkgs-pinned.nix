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
    rev = "7829e5791ba1f6e6dbddbb9b43dda72024dd2bd1";
    sha256 = "0hs9swpz0kibjc8l3nx4m10kig1fcjiyy35qy2zgzm0a33pj114w";
  };
  nixpkgs-unstable = fetch {
    rev = "8ba41a1e14961fe43523f29b8b39acb569b70e72";
    sha256 = "0c2wn7si8vcx0yqwm92dpry8zqjglj9dfrvmww6ha6ihnjl6mfhh";
  };
}
