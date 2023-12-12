nbPkgs: python3:
let
  # Ignore eval error:
  # `OpenSSL 1.1 is reaching its end of life on 2023/09/11 and cannot
  # be supported through the NixOS 23.05 release cycle.`
  # TODO-EXTERNAL: consider removing when
  # https://github.com/Simplexum/python-bitcointx/issues/76 and
  # https://github.com/JoinMarket-Org/joinmarket-clientserver#1451 are resolved.
  openssl_1_1 = python3.pkgs.pkgs.openssl_1_1.overrideAttrs (old: {
    meta = builtins.removeAttrs old.meta [ "knownVulnerabilities" ];
  });
in
rec {
  pyPkgsOverrides = self: super: let
    inherit (self) callPackage;
    clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
    joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  in
    {
      txzmq = callPackage ./txzmq {};

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # bitstring 3.1.9, required by pyln-proto
      bitstring = callPackage ./specific-versions/bitstring.nix {};

      # Packages only used by joinmarket
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      python-bitcointx = callPackage ./python-bitcointx {
        inherit (nbPkgs) secp256k1;
        openssl = openssl_1_1;
      };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};

      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

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
