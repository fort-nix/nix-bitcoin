{ lib, buildPythonPackage, fetchPypi }:
buildPythonPackage rec {
  pname = "embit";
  version = "0.4.14";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0y3pvgd0868zgz2rp41wsc6wgwfbcdcnrkhh5zdzjd3bjac40kyh";
  };

  meta = with lib; {
    description = "yet another bitcoin library";
    homepage = "https://github.com/diybitcoinhardware/embit";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
