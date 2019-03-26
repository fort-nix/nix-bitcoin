{ stdenv, fetchurl, pkgconfig, autoreconfHook, openssl, db48, boost, zeromq
, zlib, miniupnpc, qtbase ? null, qttools ? null, utillinux, protobuf, python3, qrencode, libevent
}:

with stdenv.lib;
stdenv.mkDerivation rec{
  name = "liquid-" + version;
  version = "3.14.1.22";

  src = fetchurl {
    urls = [
            "https://github.com/Blockstream/liquid/releases/download/liquid.${version}/liquid-${version}.tar.gz"
           ];
    sha256 = "25907a4085b7b92a0365235f059a12a3c82679b0049115b80697b438816e74de";
  };

  nativeBuildInputs = [ pkgconfig autoreconfHook ]
                   ++ optionals doCheck [ python3 ];
  buildInputs = [ openssl db48 boost zlib zeromq
                  miniupnpc protobuf libevent]
                  ++ optionals stdenv.isLinux [ utillinux ];

  configureFlags = [ "--with-boost-libdir=${boost.out}/lib"
                     "--disable-bench"
                   ] ++ optionals (!doCheck) [
                     "--disable-tests"
                     "--disable-gui-tests"
                   ];
  doCheck = true;

  enableParallelBuilding = true;

  meta = {
    description = "An inter-exchange settlement network based on Bitcoin";
    longDescription= ''
      Liquid is an inter-exchange settlement network linking together cryptocurrency exchanges and
      institutions around the world, enabling faster Bitcoin transactions and the issuance of
      digital assets.
    '';
    homepage = http://www.github.com/blockstream/liquid;
    license = licenses.mit;
    # liquid needs hexdump to build, which doesn't seem to build on darwin at the moment.
    platforms = platforms.linux;
  };
}
