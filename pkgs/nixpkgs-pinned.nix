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
    rev = "14006b724f3d1f25ecf38238ee723d38b0c2f4ce";
    sha256 = "07hfbilyh818pigfn342v2r05n8061wpjaf1m4h291lf6ydjagis";
  };
  nixpkgs-unstable = fetch {
    rev = "c59ea8b8a0e7f927e7291c14ea6cd1bd3a16ff38";
    sha256 = "1ak7jqx94fjhc68xh1lh35kh3w3ndbadprrb762qgvcfb8351x8v";
  };
}
