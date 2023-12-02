{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "lndinit";
  version = "0.1.3-beta";

  src = fetchFromGitHub {
    owner = "lightninglabs";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-sO1DpbppCurxr9g9nUl9Vx82FJK1mTcUw3rY1Fm1wEU=";
  };

  vendorHash = "sha256-El44BS5Bu0K/klMxkajciU/R6uqiXBMOiLN536QztbE=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Wallet initializer utility for lnd";
    homepage = "https://github.com/lightninglabs/lndinit";
    license = licenses.mit;
    maintainers = with maintainers; [ erikarvstedt ];
  };
}
