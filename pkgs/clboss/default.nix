{ lib, stdenv, fetchFromGitHub, autoconf-archive, autoreconfHook, pkgconfig, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; opensslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.13";

  src = fetchFromGitHub {
    owner = "ZmnSCPxj";
    repo = "clboss";
    rev = "v${version}";
    hash = "sha256-NP9blymdqDXo/OtGLQg/MXK24PpPvCrzqXRdtfCvpfI=";
  };

  nativeBuildInputs = [
    autoreconfHook
    autoconf-archive
    pkgconfig
    libev
    curlWithGnuTLS
    sqlite
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Automated C-Lightning Node Manager";
    homepage = "https://github.com/ZmnSCPxj/clboss";
    changelog = "https://github.com/ZmnSCPxj/clboss/blob/v${version}/ChangeLog";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = platforms.linux;
  };
}
