{ stdenv, fetchurl, pkgconfig, autoreconfHook, openssl, db48, boost, zeromq
, zlib, qtbase ? null, qttools ? null, utillinux, protobuf, python3, qrencode, libevent
}:

with stdenv.lib;
stdenv.mkDerivation rec{
  name = "elements-" + version;
  version = "0.17.0.1";

  src = fetchurl {
    urls = [
            "https://github.com/ElementsProject/elements/archive/elements-${version}.tar.gz"
           ];
    sha256 = "e106c26e7aaff043d389d70f0c5e246f556bce77c885dbfedddc67fcb45aeca0";
  };

  nativeBuildInputs = [ pkgconfig autoreconfHook ]
                   ++ optionals doCheck [ python3 ];
  buildInputs = [ openssl db48 boost zlib zeromq
                  protobuf libevent]
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
    description = "Open Source implementation of advanced blockchain features extending the Bitcoin protocol";
    longDescription= ''
      The Elements blockchain platform is a collection of feature experiments and extensions to the
      Bitcoin protocol. This platform enables anyone to build their own businesses or networks
      pegged to Bitcoin as a sidechain or run as a standalone blockchain with arbitrary asset
      tokens.
    '';
    homepage = http://www.github.com/ElementsProject/elements;
    license = licenses.mit;
    # elements needs hexdump to build, which doesn't seem to build on darwin at the moment.
    platforms = platforms.linux;
  };
}
