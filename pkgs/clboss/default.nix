{ lib, stdenv, fetchurl, pkgconfig, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; opensslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.11E";

  src = fetchurl {
    url = "https://github.com/ZmnSCPxj/clboss/releases/download/${version}/clboss-${version}.tar.gz";
    hash = "sha256-TDDD5tM3aNRxgSP/6rVM+4bX9zwcErZ0yQpQOjNU1FM=";
  };

  nativeBuildInputs = [ pkgconfig libev curlWithGnuTLS sqlite ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Automated C-Lightning Node Manager";
    homepage = "https://github.com/ZmnSCPxj/clboss";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = platforms.linux;
  };
}
