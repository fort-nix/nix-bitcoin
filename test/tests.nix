# Integration tests, can be run without internet access.

lib:
let
  # Included in all scenarios
  baseConfig = { config, pkgs, ... }: with lib; let
    cfg = config.services;
    inherit (config.nix-bitcoin.lib.test) mkIfTest;
  in {
    imports = [
      ./lib/test-lib.nix
      ../modules/modules.nix
      {
        # Features required by the Python test suite
        nix-bitcoin.secretsDir = "/secrets";
        nix-bitcoin.generateSecrets = true;
        nix-bitcoin.operator.enable = true;
        environment.systemPackages = with pkgs; [ jq ];
      }
    ];

    options.test.features = {
      clightningPlugins = mkEnableOption "all clightning plugins";
    };

    config = mkMerge [{
      environment.systemPackages = mkMerge (with pkgs; [
        # Needed to test macaroon creation
        (mkIfTest "btcpayserver" [ openssl xxd ])
        # Needed to test certificate creation
        (mkIfTest "lnd" [ openssl ])
      ]);

      tests.bitcoind = cfg.bitcoind.enable;
      services.bitcoind = {
        enable = true;
        extraConfig = mkIf config.test.noConnections "connect=0";
      };

      tests.clightning = cfg.clightning.enable;
      test.data.clightning-replication = cfg.clightning.replication.enable;

      # TODO-EXTERNAL:
      # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s.
      services.clightning.extraConfig = mkIf config.test.noConnections "disable-dns";
      test.data.clightning-plugins = let
        plugins = config.services.clightning.plugins;
        removed = [ "commando" "trustedcoin" ];
        enabled = builtins.filter (plugin: plugins.${plugin}.enable)
                                  (subtractLists removed (builtins.attrNames plugins));
        nbPkgs = config.nix-bitcoin.pkgs;
        pluginPkgs = nbPkgs.clightning-plugins // {
          clboss.path = "${nbPkgs.clboss}/bin/clboss";
        };
      in map (plugin: pluginPkgs.${plugin}.path) enabled;

      tests.clightning-rest = cfg.clightning-rest.enable;

      tests.rtl = cfg.rtl.enable;
      services.rtl = {
        nodes = {
          lnd = {
            enable = mkDefault true;
            loop = mkDefault true;
            extraConfig.Settings.userPersona = "MERCHANT";
          };
          clightning.enable = mkDefault true;
        };
        extraCurrency = mkDefault "CHF";
      };
      # Use a simple, non-random password for manual web interface tests
      nix-bitcoin.generateSecretsCmds.rtl = mkIf cfg.rtl.enable (mkForce ''
        echo a > rtl-password
      '');

      tests.lnd = cfg.lnd.enable;
      services.lnd = {
        port = 9736;
        certificate = {
          extraIPs = [ "10.0.0.1" "20.0.0.1" ];
          extraDomains = [ "example.com" ];
        };
      };

      nix-bitcoin.onionServices.lnd.public = true;

      tests.lndconnect-onion-lnd = with cfg.lnd.lndconnect; enable && onion;
      tests.lndconnect-onion-clightning = with cfg.clightning-rest.lndconnect; enable && onion;

      tests.lightning-loop = cfg.lightning-loop.enable;
      services.lightning-loop.certificate.extraIPs = [ "20.0.0.1" ];

      tests.lightning-pool = cfg.lightning-pool.enable;

      tests.charge-lnd = cfg.charge-lnd.enable;

      tests.electrs = cfg.electrs.enable;

      services.fulcrum.port = 50002;
      tests.fulcrum = cfg.fulcrum.enable;

      tests.liquidd = cfg.liquidd.enable;
      services.liquidd.extraConfig = mkIf config.test.noConnections "connect=0";

      tests.btcpayserver = cfg.btcpayserver.enable;
      services.btcpayserver = {
        lightningBackend = mkDefault "lnd";
        lbtc = mkDefault true;
      };
      test.data.btcpayserver-lbtc = config.services.btcpayserver.lbtc;

      tests.joinmarket = cfg.joinmarket.enable;
      tests.joinmarket-yieldgenerator = cfg.joinmarket.yieldgenerator.enable;
      tests.joinmarket-ob-watcher = cfg.joinmarket-ob-watcher.enable;
      services.joinmarket.yieldgenerator = {
        enable = config.services.joinmarket.enable;
        # Test a smattering of custom parameters
        ordertype = "absoffer";
        cjfee_a = 300;
        cjfee_r = 0.00003;
        txfee = 200;
      };

      tests.nodeinfo = config.nix-bitcoin.nodeinfo.enable;

      tests.backups = cfg.backups.enable;

      # To test that unused secrets are made inaccessible by 'setup-secrets'
      systemd.services.setup-secrets.preStart = mkIfTest "security" ''
        install -D -o nobody -g nogroup -m777 <(:) /secrets/dummy
      '';

      # Avoid timeout failures on slow CI nodes
      systemd.services.postgresql.serviceConfig.TimeoutStartSec = "5min";
    }
    (mkIf config.services.clightning.plugins.clboss.enable {
      # Torified 'dig' subprocesses of clboss don't respond to SIGTERM and keep
      # running for a long time when WAN is disabled, which prevents clightning units
      # from stopping quickly.
      # Set TimeoutStopSec for faster stopping.
      systemd.services.clightning.serviceConfig.TimeoutStopSec = "500ms";
    })
    (mkIf config.test.features.clightningPlugins {
      services.clightning.plugins = {
        clboss.enable = true;
        clboss.acknowledgeDeprecation = true;
        feeadjuster.enable = true;
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

  scenarios = with lib; {
    # Included in all scenarios by ./lib/make-test.nix
    base = baseConfig;

    default = scenarios.secureNode;

    # All available basic services and tests
    full = {
      tests.security = true;

      services.clightning.enable = true;
      services.clightning.replication = {
        enable = true;
        encrypt = true;
        local.directory = "/var/backup/clightning";
      };
      test.features.clightningPlugins = true;
      services.rtl.enable = true;
      services.clightning-rest.enable = true;
      services.clightning-rest.lndconnect = { enable = true; onion = true; };
      services.lnd.enable = true;
      services.lnd.lndconnect = { enable = true; onion = true; };
      services.lightning-loop.enable = true;
      services.lightning-pool.enable = true;
      services.charge-lnd.enable = true;
      services.electrs.enable = true;
      services.fulcrum.enable = true;
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
      tests.restart-bitcoind = true;

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
      services.clightning-rest.enable = true;
      services.liquidd.enable = true;
      services.rtl.enable = true;
      services.lnd.enable = true;
      services.lightning-loop.enable = true;
      services.lightning-pool.enable = true;
      services.charge-lnd.enable = true;
      services.electrs.enable = true;
      services.fulcrum.enable = true;
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
        ../modules/presets/hardened-extended.nix
      ];
    };

    netnsBase = { config, pkgs, ... }: {
      nix-bitcoin.netns-isolation.enable = true;
      test.data.netns = config.nix-bitcoin.netns-isolation.netns;
      tests.netns-isolation = true;
      environment.systemPackages = [ pkgs.fping ];
    };

    regtestBase = { config, pkgs, ... }: {
      tests.regtest = true;
      test.data.num_blocks = 100;

      services.bitcoind.regtest = true;
      systemd.services.bitcoind.postStart = mkAfter ''
        cli=${config.services.bitcoind.cli}/bin/bitcoin-cli
        if ! $cli listwallets | ${pkgs.jq}/bin/jq -e 'index("test")'; then
          "$cli" -named createwallet  wallet_name=test load_on_startup=true
          address=$($cli -rpcwallet=test getnewaddress)
          "$cli" generatetoaddress ${toString config.test.data.num_blocks} "$address"
        fi
      '';

      # lightning-loop contains no builtin swap server for regtest.
      # Add a dummy definition.
      services.lightning-loop.extraConfig = ''
        server.host=localhost
      '';

      # lightning-pool contains no builtin auction server for regtest.
      # Add a dummy definition
      services.lightning-pool.extraConfig = ''
        auctionserver=localhost
      '';

      # `validatepegin` is incompatible with regtest
      services.liquidd.validatepegin = mkForce false;

      # TODO-EXTERNAL:
      # Reenable `btcpayserver.lbtc` in regtest (and add test in tests.py)
      # when nbxplorer can parse liquidd regtest blocks.
      #
      # When `btcpayserver.lbtc` is enabled in regtest, nxbplorer tries to
      # generate regtest blocks, which fails because no liquidd wallet exists.
      # When blocks are pre-generated via `liquidd.postStart`, nbxplorer
      # fails to parse the blocks:
      #   info: NBXplorer.Indexer.LBTC: Full node version detected: 210002
      #   info: NBXplorer.Indexer.LBTC: NBXplorer is correctly whitelisted by the node
      #     fail: NBXplorer.Indexer.LBTC: Unhandled exception in the indexer, retrying in 10 seconds
      #       System.IO.EndOfStreamException: No more byte to read
      #         at NBitcoin.BitcoinStream.ReadWriteBytes(Span`1 data)
      services.btcpayserver.lbtc = mkForce false;
    };

    # Test the special bitcoin RPC setup that lnd uses when bitcoin is pruned
    lndPruned = {
      services.lnd.enable = true;
      services.bitcoind.prune = 1000;
    };

    # Test the special clightning setup where trustedcoin plugin is used
    trustedcoin = {
      tests.trustedcoin = true;
      services.clightning = {
        enable = true;
        plugins.trustedcoin.enable = true;
      };
    };
  } // (import ../dev/dev-scenarios.nix {
    inherit lib scenarios;
  });

  ## Example scenarios that showcase extra features
  exampleScenarios = with lib; {
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

    ## Scenarios with a custom Python test

    # Variant 1: Define testing code that always runs
    customTestSimple = {
      networking.hostName = "myhost";

      # Variant 1: Define testing code that always runs
      test.extraTestScript = ''
        succeed("[[ $(hostname) == myhost ]]")
      '';
    };

    # Variant 2: Define a test that can be enabled/disabled
    # via the Nix module system.
    customTestExtended = {
      networking.hostName = "myhost";

      tests.hostName = true;
      test.extraTestScript = ''
        @test("hostName")
        def _():
            succeed("[[ $(hostname) == myhost ]]")
      '';
    };
  };
in {
  inherit scenarios;

  pkgs = flake: pkgs: rec {
    # A basic test using the nix-bitcoin test framework
    makeTestBasic = import ./lib/make-test.nix flake pkgs makeTestVM;

    # Wraps `makeTest` in NixOS' testing-python.nix so that the drv includes the
    # log output and the test driver
    makeTestVM = import ./lib/make-test-vm.nix pkgs;

    # A test using the nix-bitcoin test framework, with some helpful defaults
    makeTest = { name ? "nix-bitcoin-test", config }:
      makeTestBasic {
        inherit name;
        config = {
          imports = [
            scenarios.base
            config
          ];
          # Share the same pkgs instance among tests
          nixpkgs.pkgs = pkgs.lib.mkDefault pkgs;
        };
      };

    # A test using the nix-bitcoin test framework, with defaults specific to nix-bitcoin
    makeTestNixBitcoin = { name, config }:
      makeTest {
        name = "nix-bitcoin-${name}";
        config = {
          imports = [ config ];
          test.shellcheckServices.sourcePrefix = toString ./..;
        };
      };

    makeTests = scenarios: let
      mainTests = builtins.mapAttrs (name: config:
        makeTestNixBitcoin { inherit name config; }
      ) scenarios;
    in
      {
        clightning-replication = import ./clightning-replication.nix makeTestVM pkgs;
        wireguard-lndconnect = import ./wireguard-lndconnect.nix makeTestVM pkgs;
      } // mainTests;

    tests = makeTests scenarios;

    ## Helper for ./run-tests.sh

    getTest = { name, extraScenariosFile ? null }:
      let
        tests = makeTests (scenarios // (
          lib.optionalAttrs (extraScenariosFile != null)
            (import extraScenariosFile {
              inherit scenarios lib pkgs;
              nix-bitcoin = flake;
            })
        ));
      in
        tests.${name} or (makeTestNixBitcoin {
          inherit name;
          config = {
            services.${name}.enable = true;
          };
        });

    instantiateTests = testNames:
      let
        testNames' = lib.splitString " " testNames;
      in
        map (name:
          let
            test = tests.${name};
          in
            builtins.seq (builtins.trace "Evaluating test '${name}'" test.outPath)
              test
        ) testNames';
  };
}
