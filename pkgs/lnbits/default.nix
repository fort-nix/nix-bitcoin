{ stdenv, lib, fetchurl, python3, buildPythonPackage, pythonAtLeast, nbPythonPackageOverrides, pkgs }:

let
  version = "0.8.0";
  src = fetchurl {
    url = "https://github.com/lnbits/lnbits-legend/archive/${version}.tar.gz";
    sha256 = "113p6bjfbwmchviybafhwl5s4av3mlcsz0s5zad42g2fwm4q77rh";
  };

  python = let
    packageOverrides = (self: super:
      nbPythonPackageOverrides self super
    );
  in python3.override { inherit packageOverrides; self = python; };

  pythonEnv = python.withPackages (ps: with ps; [
     bitstring cerberus ecdsa environs pyscss shortuuid typing-extensions httpx pyqrcode sqlalchemy_1_3_23 aiofiles fastapi uvicorn jinja2 starlette secp256k1 psycopg2 sqlalchemy-aio bech32 embit pycryptodomex pylightning sse-starlette lnurl
  ] );
in stdenv.mkDerivation {
  pname = "lnbits-legend";
  inherit src version;

  buildInputs = [ pythonEnv ];
  dontBuild = true;

  installPhase = ''
    mkdir -pv $out/{lib,bin}

    cp -R lnbits $out/lib

    cat <<'EOF' > "$out/bin/lnbits"
    #!${stdenv.shell}
    export PYTHONPATH=${pythonEnv}/${pythonEnv.sitePackages}
    exec ${pythonEnv.pkgs.uvicorn}/bin/uvicorn lnbits.__main__:app --port "$UVICORN_PORT" --host "$UVICORN_HOST"
    EOF

    chmod +x $out/bin/lnbits
  '';
}
