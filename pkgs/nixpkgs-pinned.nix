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
    rev = "46f9b120e836b8af69782f8ad05c4b78292cd590";
    sha256 = "1l2dqi6jpgpy3vgb6nakpx3azaryf9qg1470syn7jvpc0aq05l7z";
  };
  nixpkgs-unstable = fetch {
    rev = "88e010dcb29ecf70a973c8d57ed175eadf7f42cf";
    sha256 = "0v6g32yw3cx2qg76idkccayap6lvnhkgnw70isy4vbjd88injmpv";
  };
}
