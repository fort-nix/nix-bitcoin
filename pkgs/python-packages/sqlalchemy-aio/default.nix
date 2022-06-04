{ lib, buildPythonPackage, fetchPypi, outcome, six, sqlalchemy_1_3_23, represent }:

buildPythonPackage rec {
  pname = "sqlalchemy_aio";
  version = "0.17.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0yqznz7ys22jkz7pc7insmff4i6m5sxpfzhi1gy1vmv24sccfcgm";
  };

  propagatedBuildInputs = [ outcome represent sqlalchemy_1_3_23 ];
  doCheck = false;

  meta = with lib; {
    description = "sqlalchemy_aio adds asyncio and Trio support to SQLAlchemy core, derived from alchimia.";
    homepage = "https://github.com/RazerM/sqlalchemy_aio";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
