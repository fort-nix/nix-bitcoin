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
    rev = "95b9c99f6d091273572ff1ec62b97b6ad3f68bdf";
    sha256 = "1qcwr9binkwfayix88aljwssxi5djkwscx0rnwlk1yp9q60rgp3d";
  };
  nixpkgs-unstable = fetch {
    rev = "22a3bf9fb9edad917fb6cd1066d58b5e426ee975";
    sha256 = "089hqg2r2ar5piw9q5z3iv0qbmfjc4rl5wkx9z16aqnlras72zsa";
  };
}
