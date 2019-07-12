{ stdenvNoCC, lib, fetchurl, unzip, xxd }:

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

    # not sure if this necessary
    preInstall = ''
      # function traverseRename () {
      #   for e in *
      #   do
      #     t="$(echo "$e" | sed -e "s/%20/\ /g" -e "s/%2B/+/g")"
      #     [ "$t" != "$e" ] && mv -vn "$e" "$t"
      #     if [ -d "$t" ]
      #     then
      #       cd "$t"
      #       traverseRename
      #       cd ..
      #     fi
      #   done
      # }

      # traverseRename
   '';
  } // attrs)
