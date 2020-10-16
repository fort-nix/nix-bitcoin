{ stdenv, lib, nixos-container, openssh
, glibcLocales
}:

stdenv.mkDerivation rec {
  name = "extra-container-${version}";
  version = "0.5-pre";

  src = builtins.fetchTarball {
    url = "https://github.com/erikarvstedt/extra-container/archive/${version}.tar.gz";
    sha256 = "0gdy2dpqrdv7f4kyqz88j34x1p2fpav04kznv41hwqq88hmzap90";
  };

  buildCommand = ''
    install -D $src/extra-container $out/bin/extra-container
    patchShebangs $out/bin
    share=$out/share/extra-container
    install $src/eval-config.nix -Dt $share

    # Use existing PATH for systemctl and machinectl (for nixos-container)
    scriptPath="export PATH=${lib.makeBinPath [ nixos-container openssh ]}:\$PATH"

    sed -i \
      -e "s|evalConfig=.*|evalConfig=$share/eval-config.nix|" \
      -e "s|LOCALE_ARCHIVE=.*|LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive|" \
      -e "2i$scriptPath" \
      $out/bin/extra-container
  '';

  meta = with lib; {
    description = "Run declarative containers without full system rebuilds";
    homepage = https://github.com/erikarvstedt/extra-container;
    license = licenses.mit;
    maintainers = [ maintainers.earvstedt ];
  };
}
