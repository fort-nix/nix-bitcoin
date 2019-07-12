{ stdenv, dotnet, lib, bash, callPackage, writeText, makeWrapper, writeScript, dotnet-sdk,
  patchelf, libunwind, coreclr, libuuid, curl, zlib, icu, fetchFromGitHub }:

dotnet.mkDotNetCoreProject rec {
  baseName = "btcpayserver";
  name     = "${baseName}-${version}";
  version  = "1.0.3.122";

  project = "BTCPayServer";
  targetFramework = "netcoreapp2.1";
  nuget-pkgs = lib.importJSON (./. + "/nuget-packages-${dotnet-sdk.version}.json");

  src = fetchFromGitHub {
    owner  = baseName;
    repo   = baseName;
    rev    = "v${version}";
    sha256 = "11gb2pyzpiy20cnyr99lc5xvxhggb1mb7fjqaib7i7ch2i1b6lpz";
  };

  meta = with stdenv.lib; {
    description = "Bitcoin payment processor server";
    inherit (src.meta) homepage;
    license = licenses.mit;
    maintainers = [ maintainers.jb55 ];
    platforms = platforms.all;
  };
}
