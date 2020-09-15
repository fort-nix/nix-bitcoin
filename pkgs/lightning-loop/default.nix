{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.9.0-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "82f7c1c0c1d2ddec59c7c5e0780ae645f97ecdaca00b397cd533b27db7a6b7ca";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "1dmiiyp38biyrlmwxbrh3k8w7mxv0lsvf5qnzjrrxy6qbmglmk0l";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
