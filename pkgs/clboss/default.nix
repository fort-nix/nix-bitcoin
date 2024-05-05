{ lib, stdenv, fetchFromGitHub, autoconf-archive, autoreconfHook, pkg-config, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; opensslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "ZmnSCPxj";
    repo = "clboss";
    rev = "v${version}";
    hash = "sha256-DQvcf+y73QQYQanEvbOCOgwQzvNOXS1ZY+hVvS6N+G0=";
  };

  nativeBuildInputs = [
    autoreconfHook
    autoconf-archive
    pkg-config
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
