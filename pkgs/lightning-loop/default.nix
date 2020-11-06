{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.11.0-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "ce26d8b1bac0c53bd2bc78761c1e1b2e6233e5007686042765f1ec9fd92afc42";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "1kwcmvfk7ja8r75142k2pzinla5i921nrgbnnh4z7zxfpyh2ri4l";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
