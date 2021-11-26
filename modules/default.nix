{
  modules = ./modules.nix;
  bitcoind = ./bitcoind.nix;
  clightning = ./clightning.nix;
  default = ./default.nix;
  electrs = ./electrs.nix;
  liquid = ./liquid.nix;
  presets.secure-node = ./presets/secure-node.nix;
  rtl = ./rtl.nix;
  spark-wallet = ./spark-wallet.nix;
  lnd = ./lnd.nix;
  charge-lnd = ./charge-lnd.nix;
  joinmarket = ./joinmarket.nix;
}
