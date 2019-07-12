{ callPackage, writeText, stdenv, lib }:
rec {
  mkNugetPkgSet_ = callPackage ./make-nuget-packageset.nix {};
  fetchNuGet = callPackage ./fetchnuget.nix {};

  mkNugetPkg = pkgjson: {
    package = fetchNuGet pkgjson;
    meta = pkgjson;
  };

  mkNugetConfig = project: nuget-pkgset: writeText "${project}-nuget.config" ''
    <configuration>
    <packageSources>
        <clear />
        <add key="local" value="${nuget-pkgset}" />
    </packageSources>
    </configuration>
  '';

  mkRuntimeConfig = nuget-pkgset: writeText "runtimeconfig.json" ''
    {
      "runtimeOptions": {
        "additionalProbingPaths": [
          "${nuget-pkgset}"
        ]
      }
    }
  '';

  mkNuGetPkgs  = nugetPkgJson: map mkNugetPkg nugetPkgJson;
  mkNugetPkgSetFromJson = json: mkNugetPkgSet (mkNuGetPkgs json);
  mkNugetPkgSet = nugetPkgs: mkNugetPkgSet_ "nuget-pkgs" nugetPkgs;
}
