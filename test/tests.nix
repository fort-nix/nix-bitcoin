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
      {
        # Features required by the Python test suite
        nix-bitcoin.secretsDir = "/secrets";
        nix-bitcoin.operator.enable = true;
        environment.systemPackages = with pkgs; [ jq ];
      }
    ];

    options.test.features = {
      clightningPlugins = mkEnableOption "all clightning plugins";
    };

    config = mkMerge [{
      tests.bitcoind = cfg.bitcoind.enable;
      services.bitcoind = {
        enable = true;
        extraConfig = mkIf config.test.noConnections "connect=0";
      };

      tests.clightning = cfg.clightning.enable;
      # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s.
      services.clightning.extraConfig = mkIf config.test.noConnections "disable-dns";
      test.data.clightning-plugins = let
        plugins = config.services.clightning.plugins;
        enabled = builtins.filter (plugin: plugins.${plugin}.enable) (builtins.attrNames plugins);
        pluginPkgs = config.nix-bitcoin.pkgs.clightning-plugins;
      in map (plugin: pluginPkgs.${plugin}.path) enabled;

      tests.spark-wallet = cfg.spark-wallet.enable;

      tests.lnd = cfg.lnd.enable;
      services.lnd.port = 9736;

      tests.lnd-rest-onion-service = cfg.lnd.restOnionService.enable;

      tests.lightning-loop = cfg.lightning-loop.enable;

      tests.electrs = cfg.electrs.enable;

      tests.liquidd = cfg.liquidd.enable;
      services.liquidd.extraConfig = mkIf config.test.noConnections "connect=0";

      tests.btcpayserver = cfg.btcpayserver.enable;
      services.btcpayserver.lightningBackend = "lnd";
      # Needed to test macaroon creation
      environment.systemPackages = mkIfTest "btcpayserver" (with pkgs; [ openssl xxd ]);

      tests.joinmarket = cfg.joinmarket.enable;
      tests.joinmarket-yieldgenerator = cfg.joinmarket.yieldgenerator.enable;
      tests.joinmarket-ob-watcher = cfg.joinmarket-ob-watcher.enable;
      services.joinmarket.yieldgenerator = {
        enable = config.services.joinmarket.enable;
        customParameters = ''
          txfee = 200
          cjfee_a = 300
        '';
      };

      tests.nodeinfo = config.nix-bitcoin.nodeinfo.enable;

      tests.backups = cfg.backups.enable;

      # To test that unused secrets are made inaccessible by 'setup-secrets'
      systemd.services.generate-secrets.postStart = mkIfTest "security" ''
        install -o nobody -g nogroup -m777 <(:) /secrets/dummy
      '';
    }
    (mkIf config.test.features.clightningPlugins {
      services.clightning.plugins = {
        # TODO: add clboss when https://github.com/ZmnSCPxj/clboss/issues/49 is closed
        helpme.enable = true;
        monitor.enable = true;
        prometheus.enable = true;
        rebalance.enable = true;
        summary.enable = true;
        zmq = let tcpEndpoint = "tcp://127.0.0.1:5501"; in {
          enable = true;
          channel-opened = tcpEndpoint;
          connect = tcpEndpoint;
          disconnect = tcpEndpoint;
          invoice-payment = tcpEndpoint;
          warning = tcpEndpoint;
          forward-event = tcpEndpoint;
          sendpay-success = tcpEndpoint;
          sendpay-failure = tcpEndpoint;
        };
      };
    })
    ];
  };

  scenarios = {
    base = baseConfig; # Included in all scenarios

    default = scenarios.secureNode;

    # All available basic services and tests
    full = {
      tests.security = true;

      services.clightning.enable = true;
      test.features.clightningPlugins = true;
      services.spark-wallet.enable = true;
      services.lnd.enable = true;
      services.lnd.restOnionService.enable = true;
      services.lightning-loop.enable = true;
      services.electrs.enable = true;
      services.liquidd.enable = true;
      services.btcpayserver.enable = true;
      services.joinmarket.enable = true;
      services.joinmarket-ob-watcher.enable = true;
      services.backups.enable = true;

      nix-bitcoin.nodeinfo.enable = true;

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
      tests.secure-node = true;
      tests.banlist-and-restart = true;

      # Stop electrs from spamming the test log with 'WARN - wait until IBD is over' messages
      tests.stop-electrs = true;
    };

    netns = {
      imports = with scenarios; [ netnsBase secureNode ];
      # This test is rather slow and unaffected by netns settings
      tests.backups = mkForce false;
    };

    # All regtest-enabled services
    regtest = {
      imports = [ scenarios.regtestBase ];
      services.clightning.enable = true;
      test.features.clightningPlugins = true;
      services.spark-wallet.enable = true;
      services.lnd.enable = true;
      services.lightning-loop.enable = true;
      services.electrs.enable = true;
      services.btcpayserver.enable = true;
      services.joinmarket.enable = true;
    };

    # netns and regtest, without secure-node.nix
    netnsRegtest = {
      imports = with scenarios; [ netnsBase regtest ];
    };

    hardened = {
      imports = [
        scenarios.secureNode
        ../modules/presets/hardened.nix
      ];
    };

    netnsBase = {
      nix-bitcoin.netns-isolation.enable = true;
      test.data.netns = config.nix-bitcoin.netns-isolation.netns;
      tests.netns-isolation = true;
      environment.systemPackages = [ pkgs.fping ];
    };

    regtestBase = {
      tests.regtest = true;

      services.bitcoind.regtest = true;
      systemd.services.bitcoind.postStart = mkAfter ''
        cli=${config.services.bitcoind.cli}/bin/bitcoin-cli
        $cli createwallet "test"
        address=$($cli getnewaddress)
        $cli generatetoaddress 10 $address
      '';

      # lightning-loop contains no builtin swap server for regtest.
      # Add a dummy definition.
      services.lightning-loop.extraConfig = ''
        server.host=localhost
      '';

      # Needs wallet support which is unavailable for regtest
      services.joinmarket.yieldgenerator.enable = mkForce false;
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
