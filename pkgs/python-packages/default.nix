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
      # TODO: Remove after 2026-05-09
      clnrest = throw "`nbPython3Packages.clnrest` has been replaced with nix-bitcoin pkg `clnrest` (Rust rewrite)";

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
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  nbPython3PackagesJoinmarket = nbPython3Packages;

  # Re-enable pkgs `hwi`, `trezor` that are unaffected by `CVE-2024-23342` because
  # they don't use python pkg `ecdsa` for signing.
  # These packages no longer evaluate in nixpkgs after `ecdsa` was tagged with this CVE.
  nbPython3PackagesWithUnlockedEcdsa = let
    python3PackagesWithUnlockedEcdsa = (python3.override {
      packageOverrides = self: super: {
        ecdsa = super.ecdsa.overrideAttrs (old: {
          meta = old.meta // {
            knownVulnerabilities = builtins.filter (x: x != "CVE-2024-23342") old.meta.knownVulnerabilities;
          };
        });
      };
    }).pkgs;
  in {
    hwi = with python3PackagesWithUnlockedEcdsa; toPythonApplication hwi;
    inherit (python3PackagesWithUnlockedEcdsa) trezor;
  };
}
