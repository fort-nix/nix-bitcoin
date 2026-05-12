{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
}:
buildDotnetModule rec {
  pname = "nbxplorer";
  version = "2.6.7";

  src = fetchFromGitHub {
    owner = "dgarage";
    repo = "NBXplorer";
    tag = "v${version}";
    hash = "sha256-fA8Gv0Qc/+a8trLchXsawNk/4AdWjJCnzrwd8+rrJbw=";
  };

  projectFile = "NBXplorer/NBXplorer.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_10_0;

  # macOS has a case-insensitive filesystem, so these two can be the same file
  postFixup = ''
    mv $out/bin/{NBXplorer,nbxplorer} || :
  '';

  meta = with lib; {
    description = "Minimalist UTXO tracker for HD Cryptocurrency Wallets";
    maintainers = with maintainers; [
      kcalvinalvin
      erikarvstedt
    ];
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "nbxplorer";
  };
}
