{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-loop";
  version = "0.10.0-beta";

  src = fetchurl {
    url = "https://github.com/lightninglabs/loop/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "2c43168c72a064813427a55adb5bbb9a9aafe508d3921fc875418047bc0972a1";
  };

  subPackages = [ "cmd/loop" "cmd/loopd" ];

  vendorSha256 = "030km5fsz1x6zl93krc0nz0d9krnhqakk353b60wni5ynkgqgp3j";

  meta = with lib; {
    description = " Lightning Loop: A Non-Custodial Off/On Chain Bridge";
    homepage = "https://github.com/lightninglabs/loop";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
