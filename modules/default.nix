{
  modules = ./modules.nix;
  bitcoind = ./bitcoind.nix;
  clightning = ./clightning.nix;
  default = ./default.nix;
  electrs = ./electrs.nix;
  lightning-charge = ./lightning-charge.nix;
  liquid = ./liquid.nix;
  nanopos = ./nanopos.nix;
  presets.secure-node = ./presets/secure-node.nix;
  nix-bitcoin-webindex = ./nix-bitcoin-webindex.nix;
  spark-wallet = ./spark-wallet.nix;
  recurring-donations = ./recurring-donations.nix;
  lnd = ./lnd.nix;
}
