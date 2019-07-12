{ lib, writeScript, callPackage, stdenv, dotnet-sdk, makeWrapper, patchelf, libunwind,
  coreclr, libuuid, curl, zlib, openssl, icu, bash }:
rec {
  nuget = callPackage ./nuget.nix { };

  rpath = stdenv.lib.makeLibraryPath [ libunwind coreclr libuuid openssl stdenv.cc.cc curl zlib icu ];

  env = ''
    tmp="$(mktemp -d)"
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export HOME="$tmp"
  '';

  dotnetBuildPhase = ver: { path, target, pkgset, config, project }: ''
    ${env}
    pushd ${path}
    dotnet publish -f ${ver} -r ${target} --source ${pkgset} -c ${config} ${project}
    popd
  '';

  mkDotNetCoreProject = attrs@{
    testProjects ? []
  , project
  , src
  , meta
  , name
  , version
  , targetFramework
  , nuget-pkgs
  , installExtra ? ""
  , path ? "./"
  , config ? "Release"
  , target ? "linux-x64", ... }:
    let
      nuget-pkgset   = nuget.mkNugetPkgSetFromJson nuget-pkgs;
      nuget-config   = nuget.mkNugetConfig project nuget-pkgset;
      runtime-config = nuget.mkRuntimeConfig nuget-pkgset;

      bin-script = writeScript project ''
      #!${bash}/bin/bash
      exec ${dotnet-sdk}/bin/dotnet exec @@DEST@@/bin/${project}.dll "$@"
      '';
    in
    stdenv.mkDerivation (rec {
      inherit src version meta name;

      buildInputs = [ dotnet-sdk makeWrapper patchelf ];

      buildPhase = dotnetBuildPhase targetFramework {
        inherit path target config project;
        pkgset = nuget-pkgset;
      };

      doCheck = lib.length testProjects > 0;

      checkPhase = ''
        ${lib.concatStringsSep "\n" (map (testProject:
        let
          testProjectPkgJson = lib.importJSON (../. + "/${testProject}/nuget-packages.json");
          testPkgset         = nuget.mkNugetPkgSetFromJson testProjectPkgJson;
          testNugetConfig    = nuget.mkNugetConfig (builtins.baseNameOf testProject) testPkgset;
        in ''
          cp ${testNugetConfig} nuget.config
          dotnet test ${testProject}
          rm -f nuget.config
        '') testProjects)}
      '';

      patchPhase =
        let proj = "${path}${project}";
        in ''
        # shouldn't need tools
        sed -i '/DotNetCliToolReference/d' ${proj}/${project}.csproj || :

        ${if builtins.hasAttr "patchPhase" attrs then attrs.patchPhase proj else ""}
      '';

      installPhase = ''
        mkdir -p $out/share
        cd ${path}
        cp -r ${project}/bin/${config}/${targetFramework}/${target}/publish $out/bin
        cp ${runtime-config} $out/bin/${project}.runtimeconfig.json
        cp -r ${project}/Properties $out/bin || :


        if [ -f "$out/bin/${project}" ]
        then
          cp ${bin-script} $out/bin/${project}
          sed -i s,@@DEST@@,$out, $out/bin/${project}

          wrapProgram "$out/bin/${project}" \
            --prefix LD_LIBRARY_PATH : ${rpath}
        fi

        find $out/bin -type f -name "*.so" -exec patchelf --set-rpath "${rpath}" {} \;

        ${installExtra}
      '';

      dontStrip = true;
    });
}
