{ stdenv, lib, callPackage, dotnet-sdk_3, fetchFromGitHub }:

let
  dotnet = callPackage ./dotnet-build.nix {
    dotnet-sdk = dotnet-sdk_3;
  };
in
dotnet.mkDotNetCoreProject rec {
  project = "BTCPayServer";
  version = "1.0.4.4";
  nugetPackages = lib.importJSON (./. + "/btcpayserver-packages.json");

  src = fetchFromGitHub {
    owner = "btcpayserver";
    repo = "btcpayserver";
    rev = "v1.0.4.4";
    sha256 = "1jif63qi8571xdhgb4170ik6y7glizp01dw92a26yfzi10g41kpc";
  };

  meta = with stdenv.lib; {
    description = "Bitcoin payment server";
    license = licenses.mit;
    maintainers = [ maintainers.jb55 ];
    platforms = with platforms; linux;
  };
}
