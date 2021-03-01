{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "lightning-pool";
  version = "0.4.4-alpha";

  src = fetchurl {
    url = "https://github.com/lightninglabs/pool/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "c50f3b10a4fa7ce1afd6a00fd6c44474f44c8c773de34261e62ae805540ab140";
  };

  subPackages = [ "cmd/pool" "cmd/poold" ];

  vendorSha256 = "190qy3cz18ipv8ilpqhbaaxfi9j2isxpwhagzzspa3pwcpssrv52";

  meta = with lib; {
    description = ''
      A non-custodial batched uniform clearing-price auction for Lightning Channel Leases (LCL)
    '';
    homepage = "https://github.com/lightninglabs/pool";
    license = lib.licenses.mit;
    maintainers = with maintainers; [ sputn1ck ];
  };
}
