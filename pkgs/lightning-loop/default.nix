{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.11.1-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "ab0ee694cf3c3113a6d61098ada1953911558fa700dc6f9e90fa4ea1de44ffdb";
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
