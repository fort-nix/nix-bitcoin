{ lib, stdenv, dotnet-sdk, makeWrapper, patchelf, libunwind, writeText, fetchurl, dotnet-aspnetcore,
  libuuid, stdenvNoCC, xxd, unzip, curl, zlib, openssl, icu, writeScript, bash, callPackage, lndir, runCommand }:
rec {
  rpath = stdenv.lib.makeLibraryPath [ libunwind dotnet-aspnetcore libuuid openssl stdenv.cc.cc curl zlib icu ];

  mkNugetPkgSet_ = name: pkgs:
    let
      args = {
        preferLocalBuild = true;
        allowSubstitutes = false;
        inherit name;
      };

      make-cmd = pkg: ''
        mkdir -p $out/${pkg.meta.path}
        ${lndir}/bin/lndir -silent "${pkg.package}" "$out/${pkg.meta.path}"
      '';

    in runCommand name args
      ''
        ${lib.strings.concatStringsSep "\n" (map make-cmd pkgs)}
      '';

  fetchNuGet =
    attrs @
    { baseName
    , version
    , outputFiles
    , url ? "https://www.nuget.org/api/v2/package/${baseName}/${version}"
    , sha256 ? ""
    , sha512
    , md5 ? ""
    , ...
    }:
    if md5 != "" then
      throw "fetchnuget does not support md5 anymore, please use sha256"
    else
      let
        arrayToShell = (a: toString (map (lib.escape (lib.stringToCharacters "\\ ';$`()|<>\t") ) a));

        make-cp = outFile: ''
          outFile="${outFile}"
          [[ ''${outFile: -7} == ".sha512" ]] && echo -n "${sha512}" \
            | ${lib.getBin xxd}/bin/xxd -r -p \
            | base64 -w500 > ${outFile}
          cp -r --parents -t $out "${outFile}" || :
        '';

        nupkg-name = lib.strings.toLower "${baseName}.${version}.nupkg";
      in
      stdenvNoCC.mkDerivation ({
        name = "${baseName}-${version}";

        src = fetchurl {
          inherit url sha256;
          name = "${baseName}.${version}.zip";
        };

        sourceRoot = ".";

        buildInputs = [ unzip ];

        dontStrip = true;

        installPhase = ''
          mkdir -p $out
          chmod +r *.nuspec
          cp *.nuspec $out
          cp $src $out/${nupkg-name}
          ${lib.strings.concatStringsSep "\n" (map make-cp outputFiles)}
        '';

      } // attrs);

  mkNugetPkg = pkgjson: {
    package = fetchNuGet pkgjson;
    meta = pkgjson;
  };

  mkNuGetPkgs  = nugetPkgJson: map mkNugetPkg nugetPkgJson;
  mkNugetPkgSet = nugetPkgs: mkNugetPkgSet_ "nuget-pkgs" nugetPkgs;
  mkNugetPkgSetFromJson = json: mkNugetPkgSet (mkNuGetPkgs json);

  env = ''
    tmp="$(mktemp -d)"
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export HOME="$tmp"
  '';

  dotnetBuildPhase = buildPhase;

  buildPhase = { path, target, pkgset, config, project }: ''
    ${env}
    pushd ${path}
    mkdir -p $out/libexec/${project}
    printf "building with ${pkgset}\n"
    dotnet publish --source ${pkgset} -c ${config} ${project} -o $out/libexec/${project}
    popd
  '';

mkDotNetCoreProject = attrs@{
    testProjects ? []
  , project
  , src
  , meta
  , nugetPackages ? null
  , installExtra ? ""
  , path ? "./"
  , config ? "Release"
  , target ? "linux-x64", ... }:
    let
      nuget-pkg-json = if nugetPackages == null
                          then lib.importJSON (lesrc + "/${path}${project}/nuget-packages.json")
                          else nugetPackages;
      nuget-pkgset   = mkNugetPkgSetFromJson nuget-pkg-json;

      bin-script = writeScript project ''
        #!${bash}/bin/bash
	cd @@DEST@@/libexec/${project}
        exec ${dotnet-sdk}/bin/dotnet exec ${project}.dll "$@"
      '';

      lesrc = src;
    in
    stdenv.mkDerivation (rec {
      pname = project;
      version = attrs.version;

      buildInputs = [ dotnet-sdk makeWrapper patchelf ];

      inherit src;

      buildPhase = dotnetBuildPhase {
        inherit path target config project;
        pkgset = nuget-pkgset;
      };

      doCheck = lib.length testProjects > 0;

      checkPhase = ''
	printf "checking...\n"
        ${lib.concatStringsSep "\n" (map (testProject:
        let
          testProjectPkgJson = lib.importJSON (lesrc + "/${testProject}/nuget-packages.json");
          testPkgset         = mkNugetPkgSetFromJson testProjectPkgJson;
        in ''
          dotnet test --source ${testPkgset} ${testProject}
        '') testProjects)}
      '';

      patchPhase =
        let proj = "${path}${project}/${project}";
        in ''
        # shouldn't need tools
        sed -i '/DotNetCliToolReference/d' ${proj}.csproj || :
        sed -i '/DotNetCliToolReference/d' ${proj}.csproj || :
	${if builtins.hasAttr "patchPhase" attrs then attrs.patchPhase else ""}
      '';

      installPhase = ''
        mkdir -p $out/libexec/${project} $out/bin
        cd ${path}

        if [ -f "$out/libexec/${project}/${project}" ]
        then
          <${bin-script} sed "s,@@DEST@@,$out," > $out/bin/${project}
          chmod +x $out/bin/${project}

          wrapProgram "$out/bin/${project}" --prefix LD_LIBRARY_PATH : ${rpath}
        fi

        find $out/bin -type f -name "*.so" -exec patchelf --set-rpath "${rpath}" {} \;

        ${installExtra}
      '';

      dontStrip = true;

      inherit meta;
    });
}
