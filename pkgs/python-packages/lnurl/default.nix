{ lib, buildPythonPackage, fetchPypi, pydantic, bech32 }:
buildPythonPackage rec {
  pname = "lnurl";
  version = "0.3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1xilh8xahqb51ykckd3abxyqkqxyc9h9m72s589g6j2s25h79w4a";
  };

  propagatedBuildInputs = [ pydantic bech32 ];

  meta = with lib; {
    description = "A collection of helpers for building LNURL support into wallets and services.";
    homepage = "https://github.com/lnbits/lnurl";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
