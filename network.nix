let
  secrets = import ./load-secrets.nix;
in {
  network.description = "Bitcoin Core node";

  bitcoin-node = import ./configuration.nix;
}
