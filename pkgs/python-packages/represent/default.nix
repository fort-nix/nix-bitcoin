{ lib, buildPythonPackage, fetchPypi, six }:
buildPythonPackage rec {
  pname = "Represent";
  version = "1.6.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "12pprv1j5liadlcgj14c1ihcp7h0rp1gx6x44451bqp9nb4gwg99";
  };

  propagatedBuildInputs = [ six ];
  doCheck = false;

  meta = with lib; {
    description = "Create __repr__ automatically or declaratively. ";
    homepage = "https://github.com/RazerM/represent";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
