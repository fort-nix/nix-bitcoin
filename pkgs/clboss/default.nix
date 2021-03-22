{ lib, stdenv, fetchurl, pkgconfig, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; sslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.10";

  src = fetchurl {
    url = "https://github.com/ZmnSCPxj/clboss/releases/download/v${version}/clboss-${version}.tar.gz";
    sha256 = "1bmlpfhsjs046qx2ikln15rj4kal32752zs1s5yjklsq9xwnbciz";
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
