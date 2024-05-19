nbPkgs: python3:
rec {
  pyPkgsOverrides = self: super: let
    inherit (self) callPackage;
    clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
  in
    {
      txzmq = callPackage ./txzmq {};

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # Packages only used by joinmarket
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      python-bitcointx = callPackage ./python-bitcointx { inherit (self.pkgs) secp256k1; };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};

      joinmarket = callPackage ./joinmarket { inherit (nbPkgs.joinmarket) version src; };

      ## Specific versions of packages that already exist in nixpkgs

      # autobahn 20.12.3, required by joinmarketclient
      autobahn = callPackage ./specific-versions/autobahn.nix {};

      # A version of `buildPythonPackage` which checks that Python package
      # requirements are met.
      # This was the case for NixOS <= 23.05.
      # TODO-EXTERNAL: Remove when this is resolved:
      # https://github.com/NixOS/nixpkgs/issues/253131
      buildPythonPackageWithDepsCheck = attrs:
        self.buildPythonPackage (attrs // {
          dontUsePypaInstall = true;
          nativeBuildInputs = (attrs.nativeBuildInputs or []) ++ [ self.pipInstallHook ];
        });
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  nbPython3PackagesJoinmarket = nbPython3Packages;
}
