{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "faraday";
  version = "0.2.3-alpha";

  src = fetchurl {
    url = "https://github.com/lightninglabs/faraday/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "c016e2b16160f24abdfce0f71cdb848da3e3d78cff450fb353017d4104bd616e";
  };

  subPackages = [ "cmd/faraday" "cmd/frcli" ];

  vendorSha256 = "1hh99nfprlmhkc36arg3w1kxby59i2l7n258cp40niv7bjn37hrq";

  meta = with lib; {
    description = " Faraday: Lightning Channel Management & Optimization Tool";
    homepage = "https://github.com/lightninglabs/faraday";
    license = lib.licenses.mit;
  };
}
