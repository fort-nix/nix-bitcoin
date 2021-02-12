{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.11.3-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "b9eebf39543e7d0cd50ebb29242578146b25781fd5f6ac4c2b7c93448fb65448";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "1xml5mbjnp3hs1qmzz98ivjq438l816pphw6iyjjkq44pifnglrz";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
