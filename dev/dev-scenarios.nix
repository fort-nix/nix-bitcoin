# Extra scenarios for developing and debugging

{ lib, scenarios }:

with lib;
{
  btcpayserver-regtest = {
    imports = [ scenarios.regtestBase ];
    services.btcpayserver.enable = true;
    test.container.exposeLocalhost = true;
    # services.btcpayserver.lbtc = false;
  };

  # A node with internet access to test joinmarket-ob-watcher
  jm-ob-watcher = {
    services.joinmarket-ob-watcher.enable = true;
    # Don't download blocks
    services.bitcoind.extraConfig = ''
      connect = 0;
    '';
    test.container.exposeLocalhost = true;
    test.container.enableWAN = true;
  };

  rtl-dev = { config, pkgs, lib, ... }: {
    imports = [
      # scenarios.netnsBase
      # scenarios.regtestBase
    ];
    services.rtl = {
      enable = true;
      nodes.clightning = {
        enable = true;
        extraConfig.Settings.themeColor = "INDIGO";
      };
      # nodes.lnd.enable = false;
      # services.rtl.nodes.reverseOrder = true;
      nightTheme = true;
      extraCurrency = "CHF";
    };
    test.container.exposeLocalhost = true;
    nix-bitcoin.nodeinfo.enable = true;
    # test.container.enableWAN = true;
  };
}
