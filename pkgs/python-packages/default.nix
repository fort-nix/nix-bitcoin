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
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

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

    # nixpkgs has keyring 25.6.0, but trezor 0.20.0 requires >= 25.7.0.
    # 25.7.0 only adds KWallet 6 support and removes Python 3.8 cruft,
    # so 25.6.0 is functionally equivalent for trezor's use.
    # Relax the constraint until nixpkgs updates keyring.
    trezor = python3PackagesWithUnlockedEcdsa.trezor.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
        python3PackagesWithUnlockedEcdsa.pythonRelaxDepsHook
      ];
      pythonRelaxDeps = [ "keyring" ];
    });
  };
}
