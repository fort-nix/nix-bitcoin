# Integration tests, can be run without internet access.

{ scenario ? "default" }:

import ./lib/make-test.nix scenario (
{ config, pkgs, lib, ... }: with lib;
let testEnv = rec {
  cfg = config.services;
  mkIfTest = test: mkIf (config.tests.${test} or false);

  baseConfig = {
    imports = [
      ./lib/test-lib.nix
      ../modules/modules.nix
      ../modules/secrets/generate-secrets.nix
    ];

    config = {
      tests.bitcoind = cfg.bitcoind.enable;
      services.bitcoind = {
        enable = true;
        extraConfig = mkIf config.test.noConnections "connect=0";
      };

      tests.clightning = cfg.clightning.enable;

      tests.spark-wallet = cfg.spark-wallet.enable;

      tests.nanopos = cfg.nanopos.enable;

      tests.lnd = cfg.lnd.enable;
      services.lnd.listenPort = 9736;

      tests.lightning-loop = cfg.lightning-loop.enable;

      tests.electrs = cfg.electrs.enable;

      tests.liquidd = cfg.liquidd.enable;
      services.liquidd.extraConfig = mkIf config.test.noConnections "connect=0";

      tests.btcpayserver = cfg.btcpayserver.enable;
      services.btcpayserver.lightningBackend = "lnd";
      # Needed to test macaroon creation
      environment.systemPackages = mkIfTest "btcpayserver" (with pkgs; [ openssl xxd ]);

      tests.joinmarket = cfg.joinmarket.enable;
      services.joinmarket.yieldgenerator = {
        enable = config.services.joinmarket.enable;
        customParameters = ''
          txfee = 200
          cjfee_a = 300
        '';
      };

      tests.backups = cfg.backups.enable;

      # To test that unused secrets are made inaccessible by 'setup-secrets'
      systemd.services.generate-secrets.postStart = mkIfTest "security" ''
        install -o nobody -g nogroup -m777 <(:) /secrets/dummy
      '';
    };
  };

  scenarios = {
    base = baseConfig; # Included in all scenarios

    default = scenarios.secureNode;

    # All available basic services and tests
    full = {
      tests.security = true;

      services.clightning.enable = true;
      services.spark-wallet.enable = true;
      services.lightning-charge.enable = true;
      services.nanopos.enable = true;
      services.lnd.enable = true;
      services.lightning-loop.enable = true;
      services.electrs.enable = true;
      services.liquidd.enable = true;
      services.btcpayserver.enable = true;
      services.joinmarket.enable = true;
      services.backups.enable = true;

      services.hardware-wallets = {
        trezor = true;
        ledger = true;
      };
    };

    secureNode = {
      imports = [
        scenarios.full
        ../modules/presets/secure-node.nix
      ];
      services.nix-bitcoin-webindex.enable = true;
      tests.secure-node = true;
      tests.banlist-and-restart = true;
    };

    netns = {
      imports = [ scenarios.secureNode ];
      nix-bitcoin.netns-isolation.enable = true;
      test.data.netns = config.nix-bitcoin.netns-isolation.netns;
      tests.netns-isolation = true;

      # This test is rather slow and unaffected by netns settings
      tests.backups = mkForce false;
    };

    ## Examples / debug helper

    # Run a selection of tests in scenario 'netns'
    selectedTests = {
      imports = [ scenarios.netns ];
      tests = mkForce {
        btcpayserver = true;
        netns-isolation = true;
      };
    };

    # Container-specific features
    containerFeatures = {
      # Container has WAN access and bitcoind connects to external nodes
      test.container.enableWAN = true;
      # See ./lib/test-lib.nix for a description
      test.container.exposeLocalhost = true;
    };

    adhoc = {
      # <Add your config here>
      # You can also set the env var `scenarioOverridesFile` (used below) to define custom scenarios.
    };
  };
};
in
  let
    overrides = builtins.getEnv "scenarioOverridesFile";
    scenarios = testEnv.scenarios // (optionalAttrs (overrides != "") (import overrides {
      inherit testEnv config pkgs lib;
    }));
    autoScenario = {
      services.${scenario}.enable = true;
    };
  in {
    imports = [
      scenarios.base
      (scenarios.${scenario} or autoScenario)
    ];
  }
)
