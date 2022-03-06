{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
}:

stdenv.mkDerivation {
  pname = "secp256k1";

  version = "2021-12-03";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "secp256k1";
    rev = "490022745164b56439688b0fc04f9bd43578e5c3";
    hash = "sha256-6CmGWiecthaGWSKX7VHWj5zvDAwVE9U5YOo9JRJWYwI=";
  };

  nativeBuildInputs = [ autoreconfHook ];

  configureFlags = [
    "--enable-benchmark=no"
    "--enable-exhaustive-tests=no"
    "--enable-experimental"
    "--enable-module-ecdh"
    "--enable-module-recovery"
    "--enable-module-schnorrsig"
  ];

  doCheck = true;

  checkPhase = "./tests";

  meta = with lib; {
    description = "Optimized C library for EC operations on curve secp256k1";
    longDescription = ''
      Optimized C library for EC operations on curve secp256k1. Part of
      Bitcoin Core. This library is a work in progress and is being used
      to research best practices. Use at your own risk.
    '';
    homepage = "https://github.com/bitcoin-core/secp256k1";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = with platforms; unix;
  };
}
