{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.8.1-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "36815049c7807b1f0b2b0694ae64b2ec23819240952cb327c9b9e0d530ac4696";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "0y1j4ca4njx9fyyq3qv8hmcvs5ig6kyx6hhp1bdby7wgmlc0s5vp";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
