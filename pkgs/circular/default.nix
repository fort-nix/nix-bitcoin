{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "circular";
  version = "1.1.1";
  src = fetchFromGitHub {
    owner = "giovannizotta";
    repo = pname;
    rev = "0735c9e7da834b7690f490a9c8ea7286f7dbfe72";
    sha256 = "sha256-LQ4O+JhIe2WvXCFQ5djxrVqvW3KwtaNlJpTgmIKQay4=";
  };

  vendorSha256 = "sha256-bkHfGp6zyLGmKqNz6ECYxWWEQNOvDs219sk0eS6A2nQ=";

  meta = with lib; {
    description = "circular is a CLN plugin that helps nodes rebalance their channels";
    homepage = "https://github.com/giovannizotta/circular";
    maintainers = with maintainers; [ jurraca ];
    platforms = platforms.linux;
  };
}
