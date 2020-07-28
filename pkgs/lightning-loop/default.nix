{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.7.0-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "fbb5ae6dd55002a632a924e41a0bb2ce886eb9e834668be35b312b14e8b68233";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "1g0l09zcic5nnrsdyap40dj3zl59gbb2k8iirhph3257ysa52mhr";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
