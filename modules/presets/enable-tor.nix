{ lib, config, ... }:
let
  defaultTrue = lib.mkDefault true;
  defaultEnableTorProxy = {
    tor.proxy = defaultTrue;
    tor.enforce = defaultTrue;
  };
  defaultEnforceTor = {
    tor.enforce = defaultTrue;
  };
in {
  services.tor = {
    enable = true;
    client.enable = true;
  };

  services = {
    # Use Tor as a proxy for outgoing connections
    # and restrict all connections to Tor
    #
    bitcoind = defaultEnableTorProxy;
    clightning = defaultEnableTorProxy;
    lnd = defaultEnableTorProxy;
    lightning-loop = defaultEnableTorProxy;
    liquidd = defaultEnableTorProxy;
    # TODO-EXTERNAL:
    # disable Tor enforcement until btcpayserver can fetch rates over Tor
    # btcpayserver = defaultEnableTorProxy;
    lightning-pool = defaultEnableTorProxy;
    mempool = defaultEnableTorProxy;

    # These services don't make outgoing connections but we restrict them to
    # Tor just to be safe.
    #
    electrs = defaultEnforceTor;
    fulcrum = defaultEnforceTor;
    nbxplorer = defaultEnforceTor;
    rtl = defaultEnforceTor;
    clightning-rest = defaultEnforceTor;
  };

  # Add onion services for incoming connections
  nix-bitcoin.onionServices = {
    bitcoind.enable = defaultTrue;
    liquidd.enable = defaultTrue;
    electrs.enable = defaultTrue;
    fulcrum.enable = defaultTrue;
    rtl.enable = defaultTrue;
  };
}
