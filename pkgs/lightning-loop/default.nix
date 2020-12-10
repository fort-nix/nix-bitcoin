{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.11.2-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "88fb0f1560a551778407f45a537de67366fe60d2c77e5bdff0e60b562cdb571b";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "1mpsnalh22gzkggiqsfyccsdji7ilw19ck7ymhjanxa2r11j9ncc";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
