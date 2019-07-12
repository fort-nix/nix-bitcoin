{ stdenv, lib, bash, dotnet, callPackage, writeText, makeWrapper,
  writeScript, dotnet-sdk, patchelf, libunwind, coreclr, libuuid, curl,
  zlib, icu, fetchFromGitHub }:

dotnet.mkDotNetCoreProject rec {
  name    = "NBXplorer";
  project = name;
  version = "2.0.0.52";
  config  = "Release";

  targetFramework = "netcoreapp2.1";
  nuget-pkgs = lib.importJSON (./. + "/nuget-packages-${dotnet-sdk.version}.json");

  src = fetchFromGitHub {
    owner  = "dgarage";
    repo   = project;
    rev    = "v${version}";
    sha256 = "0749z0cb3mqwm5r5qz0q9yqj3ipcwym01ghnacwypm186y58c9dd";
  };

  patchPhase = proj: ''
    # they shouldn't be setting an explicit version of this...
    sed -i 's/Version="2.1.9"//' ${proj}/${project}.csproj
  '';

  meta = with stdenv.lib; {
    description = "Block explorer/utxo watcher used by btcpayserver";
    inherit (src.meta) homepage;
    license = licenses.mit;
    maintainers = [ maintainers.jb55 ];
    platforms = platforms.all;
  };
}
