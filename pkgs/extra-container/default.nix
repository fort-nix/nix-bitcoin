{ stdenv, lib, nixos-container, openssh
, glibcLocales
}:

stdenv.mkDerivation rec {
  pname = "extra-container";
  version = "0.6";

  src = builtins.fetchTarball {
    url = "https://github.com/erikarvstedt/extra-container/archive/${version}.tar.gz";
    sha256 = "0hm4xfjbqjrrq7n1pkbs33lpw9k5q3ms3psprqhfsxkkwzy78zlm";
  };

  buildCommand = ''
    install -D $src/extra-container $out/bin/extra-container
    patchShebangs $out/bin
    share=$out/share/extra-container
    install $src/eval-config.nix -Dt $share

    # Use existing PATH for systemctl and machinectl
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
