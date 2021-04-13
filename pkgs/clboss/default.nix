{ lib, stdenv, fetchurl, pkgconfig, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; sslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.11A";

  src = fetchurl {
    url = "https://github.com/ZmnSCPxj/clboss/releases/download/${version}/clboss-${version}.tar.gz";
    sha256 = "1vxa1f3jwlybdca2da73a1fnqy55c4ipwwysvkhy74sw5b4q905g";
  };

  nativeBuildInputs = [ pkgconfig libev curlWithGnuTLS sqlite ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Automated C-Lightning Node Manager";
    homepage = "https://github.com/ZmnSCPxj/clboss";
    maintainers = with maintainers; [ nixbitcoin ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
