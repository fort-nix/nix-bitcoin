{ lib, stdenv, fetchFromGitHub, autoreconfHook }:

stdenv.mkDerivation {
  pname = "secp256k1";

  version = "2019-10-11";

  src = fetchFromGitHub {
    owner = "bitcoin-core";
    repo = "secp256k1";
    rev = "0d9540b13ffcd7cd44cc361b8744b93d88aa76ba";
    sha256 = "05zwhv8ffzrfdzqbsb4zm4kjdbjxqy5jh9r83fic0qpk2mkvc2i2";
  };

  nativeBuildInputs = [ autoreconfHook ];

  configureFlags = ["--enable-module-recovery" "--disable-jni" "--enable-experimental" "--enable-module-ecdh" "--enable-benchmark=no" ];

  meta = with lib; {
    description = "Optimized C library for EC operations on curve secp256k1";
    homepage = "https://github.com/bitcoin-core/secp256k1";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = with platforms; unix;
  };
}
