# This flake just mirrors input `nixos-search`.
# Because `nixos-search` is a dev-only dependency, we don't add
# it to the main flake.
{
  inputs.nixos-search.url = "github:nixos/nixos-search";
  outputs = { self, nixos-search }: {
    inherit (nixos-search) packages;

    # Used by ./ci-test.sh
    inherit (nixos-search.inputs.nixpkgs) legacyPackages;
    nixpkgsPath = toString nixos-search.inputs.nixpkgs;
  };
}
