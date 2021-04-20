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
    rev = "5438e11ea34adf2b8111d80e360442077476ff53";
    sha256 = "14r88yiz69b828hxq1i5xwy63xa4cwzaa88xa4ig05sfsmrf04q1";
  };
  nixpkgs-unstable = fetch {
    rev = "3d1a7716d7f1fccbd7d30ab3b2ed3db831f43bde";
    sha256 = "14r8qa6lnzp78c3amzi5r8n11l1kcxcx1gjhnc1kmn4indd43649";
  };
}
