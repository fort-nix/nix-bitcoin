{ stdenv, lib, callPackage, dotnet-sdk_3, fetchFromGitHub }:

let
  dotnet = callPackage ./dotnet-build.nix {
    dotnet-sdk = dotnet-sdk_3;
  };
in
dotnet.mkDotNetCoreProject rec {
  project = "NBXplorer";
  version = "2.1.26";
  nugetPackages = lib.importJSON (./. + "/nbxplorer-packages.json");

  src = fetchFromGitHub {
    owner = "dgarage";
    repo  = "NBXplorer";
    rev   = "v${version}";
    sha256 = "1xpv86vbdwdlrfj5qks1ca0zfm73lsmgyp5y5h263jh9fj45xs8w";
  };

  meta = with stdenv.lib; {
    description = "dotnet Bitcoin chain source for BTCPayServer";
    license = licenses.mit;
    maintainers = [ maintainers.jb55 ];
    platforms = with platforms; linux;
  };
}
