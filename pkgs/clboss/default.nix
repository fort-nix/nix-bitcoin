{ lib, stdenv, fetchurl, fetchpatch, pkgconfig, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; opensslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.13A";

  src = fetchurl {
    url = "https://github.com/ZmnSCPxj/clboss/releases/download/${version}/clboss-${version}.tar.gz";
    hash = "sha256-LTDJrm9Mk4j7Z++tKJKawEurgF1TnYuIoj+APbDHll4=";
  };

  patches = [
    # https://github.com/ZmnSCPxj/clboss/pull/162, required for clighting 23.05
    (fetchpatch {
      name = "fix-json-rpc";
      url = "https://github.com/ZmnSCPxj/clboss/commit/a4bb0192550803db3d07628a29284a76f7204365.patch";
      sha256 = "sha256-1iBJlOnt7n2xXNDgzH3PAvLryZcpM4VWNaWcEegbapQ=";
    })
  ];

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
