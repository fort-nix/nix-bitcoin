{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.12.2-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "b2fbacdd8b2311b2f9873fa479e399ef7a09cc038b5c8449f9183b0038d81cc3";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "03z0cmn9qgcmqm8llybfn1hz1m9hx3pn18m11s3fwnay8ib00r89";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
