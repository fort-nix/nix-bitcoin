{ lib, buildPythonPackage, fetchPypi }:
buildPythonPackage rec {
  pname = "urldecode";
  version = "0.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0w8my7kdwxppsfzzi1b2cxhypm6r1fsrnb2hnd752axq4gfsddjj";
  };

  meta = with lib; {
    description = "A simple function to decode an encoded url";
    homepage = "https://github.com/jennyq/urldecode";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
