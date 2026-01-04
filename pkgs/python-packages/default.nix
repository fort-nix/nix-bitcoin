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
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  # joinmarket requires cython 3.0 via pkg bencoder.pyx.
  # The python pkgs from nixpkgs-25.11 default to cython 3.1.
  # Downgrading to 3.0 causes mass rebuilds, so we use python pkgs from nixpkgs-25.05 for joinmarket.
  # The nixpkgs-25.05 dependency will be removed with the next joinmarket update.
  # https://github.com/JoinMarket-Org/joinmarket-clientserver/issues/1787
  nbPython3PackagesJoinmarket =
    (nbPkgs.pinned.pkgs-25_05.python3.override {
      packageOverrides = self: super:
        (pyPkgsOverrides self super) // {
          ## Specific versions of packages that already exist in nixpkgs

          # autobahn 20.12.3, required by joinmarketclient
          autobahn = self.callPackage ./specific-versions/autobahn.nix {};
        };
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

    # trezor 0.13.10 supports click 8.2.x.
    # The version spec `click>=8,<8.3` has been copied from trezor 0.20.0-dev.
    trezor = python3PackagesWithUnlockedEcdsa.trezor.overridePythonAttrs (_: {
      postPatch = ''
        substituteInPlace requirements.txt \
          --replace-fail 'click>=7,<8.2' 'click>=8,<8.3'
      '';
    });
  };
}
