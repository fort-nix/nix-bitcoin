{ lib, buildPythonPackage, fetchPypi }:
buildPythonPackage rec {
  pname = "bech32";
  version = "1.2.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "16fq5cfy5id9hp123ylhpl55pf38xwk0hv7sziqpig838qhvhvbx";
  };

  meta = with lib; {
    description = "Reference implementation for Bech32 and segwit addresses.";
    homepage = "https://github.com/fiatjaf/bech32";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
