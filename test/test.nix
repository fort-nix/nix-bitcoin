# Integration test, can be run without internet access.

{ scenario ? "default" }:

let
  netns-isolation = builtins.getAttr scenario { default = false; withnetns = true; };
  testScriptFilename = builtins.getAttr scenario { default = ./scenarios/default.py; withnetns = ./scenarios/withnetns.py; };
in

import ./make-test.nix rec {
  name = "nix-bitcoin-${scenario}";

  hardened = {
    imports = [ <nixpkgs/nixos/modules/profiles/hardened.nix> ];
    security.allowUserNamespaces = true; # re-enable disabled option
  };

  machine = { pkgs, lib, ... }: with lib; {
    imports = [
      ../modules/presets/secure-node.nix
      ../modules/secrets/generate-secrets.nix
      # using the hardened profile increases total test duration by ~50%, so disable it for now
      # hardened
    ];

    nix-bitcoin.netns-isolation.enable = mkForce netns-isolation;

    services.bitcoind.extraConfig = mkForce "connect=0";

    services.clightning.enable = true;
    services.spark-wallet.enable = true;
    services.lightning-charge.enable = true;
    services.nanopos.enable = true;

    services.lnd.enable = true;
    services.lnd.listenPort = 9736;
    services.lightning-loop.enable = true;
    # needed because we must control when lightning-loop starts so it doesn't
    # fail before we run commands in the nb-lightning-loop netns
    systemd.services.lightning-loop.wantedBy = mkForce [];

    services.electrs.enable = true;

    services.liquidd = {
      enable = true;
      listen = mkForce false;
      extraConfig = "noconnect=1";
    };

    services.nix-bitcoin-webindex.enable = true;

    services.hardware-wallets = {
      trezor = true;
      ledger = true;
    };

    services.backups.enable = true;

    # to test that unused secrets are made inaccessible by 'setup-secrets'
    systemd.services.generate-secrets.postStart = ''
      install -o nobody -g nogroup -m777 <(:) /secrets/dummy
    '';
  };
  testScript = builtins.readFile ./scenarios/lib.py + "\n\n" + builtins.readFile testScriptFilename;
}
