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
    rev = "42674051d12540d4a996504990c6ea3619505953";
    sha256 = "1hz1n1hghilgzk4zlya498xm5lvhsf0r5b49yii7q86h3616fhwy";
  };
  nixpkgs-unstable = fetch {
    rev = "a31736120c5de6e632f5a0ba1ed34e53fc1c1b00";
    sha256 = "0xfjizw6w84w1fj47hxzw2vwgjlszzmsjb8k8cgqhb379vmkxjfl";
  };
}
