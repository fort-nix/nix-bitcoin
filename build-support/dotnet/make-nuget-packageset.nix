{ lndir, runCommand, lib }:
name: pkgs:
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
  ''
