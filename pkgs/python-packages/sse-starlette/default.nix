{ lib, buildPythonPackage, fetchPypi, starlette, uvicorn, fastapi, anyio }:
buildPythonPackage rec {
  pname = "sse-starlette";
  version = "0.10.3";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1m1bir17kwb2jx7y8giwmdy7x26a1rgs4244dz3hqdk1sgz0f1l4";
  };

  propagatedBuildInputs = [ starlette uvicorn fastapi anyio ];
  doCheck = false;

  meta = with lib; {
    description = "Server Sent Events for Starlette and FastAPI";
    homepage = "https://github.com/sysid/sse-starlette";
    maintainers = with maintainers; [ nixbitcoin ];
  };
}
