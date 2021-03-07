{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.12.0-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "95b34bdb54bcf96bda4b2914688244fff8d913fcbc697703b1ec048b39620e23";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "0r0k6b3pml9silwdzvbvbhgcjk6nf9rp6incyqkwr9kdc2fl0dcw";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
