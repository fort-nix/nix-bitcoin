{ stdenv, lib }:

stdenv.mkDerivation rec {
  name = "extra-container-${version}";
  version = "0.3";

  src = builtins.fetchTarball {
    url = "https://github.com/erikarvstedt/extra-container/archive/6cced2c26212cc1c8cc7cac3547660642eb87e71.tar.gz";
    sha256 = "0qr41mma2iwxckdhqfabw3vjcbp2ffvshnc3k11kwriwj14b766v";
  };

  buildCommand = ''
    install -D $src/extra-container $out/bin/extra-container
    patchShebangs $out/bin
    install $src/eval-config.nix -Dt $out/src
    sed -i "s|evalConfig=.*|evalConfig=$out/src/eval-config.nix|" $out/bin/extra-container
  '';

  meta = with lib; {
    description = "Run declarative containers without full system rebuilds";
    homepage = https://github.com/erikarvstedt/extra-container;
    license = licenses.mit;
    maintainers = [ maintainers.earvstedt ];
  };
}
