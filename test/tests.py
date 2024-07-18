from collections import OrderedDict
import json
import re

def succeed(*cmds):
    """Returns the concatenated output of all cmds"""
    return machine.succeed(*cmds)

def assert_matches(cmd, regexp):
    assert_str_matches(succeed(cmd), regexp)

def assert_str_matches(str, regexp):
    if not re.search(regexp, str):
        raise Exception(f"Pattern '{regexp}' not found in '{str}'")

def assert_full_match(cmd, regexp):
    out = succeed(cmd)
    if not re.fullmatch(regexp, out):
        raise Exception(f"Pattern '{regexp}' doesn't match '{out}'")

def log_has_string(unit, str):
    return f"journalctl -b --output=cat -u {unit} --grep='{str}'"

def assert_no_failure(unit):
    """Unit should not have failed since the system is running"""
    machine.fail(log_has_string(unit, "Failed with result"))

def assert_running(unit):
    with machine.nested(f"waiting for unit: {unit}"):
        machine.wait_for_unit(unit)
    assert_no_failure(unit)

def wait_for_open_port(address, port):
    def is_port_open(_):
        status, _ = machine.execute(f"nc -z {address} {port}")
        return status == 0

    with machine.nested(f"Waiting for TCP port {address}:{port}"):
        retry(is_port_open)


### Test runner

tests = OrderedDict()

def test(name):
    def x(fn):
        tests[name] = fn
    return x

# `run_tests` is already defined by the NixOS test driver
def nb_run_tests():
    enabled = enabled_tests.copy()
    to_run = []
    for test in tests:
        if test in enabled:
            enabled.remove(test)
            to_run.append(test)
    if enabled:
        raise RuntimeError(f"The following tests are enabled but not defined: {enabled}")
    machine.connect()  # Visually separate boot output from the test output
    for test in to_run:
        with machine.nested(f"test: {test}"):
            tests[test]()

def run_test(test):
    tests[test]()


### Tests
# All tests are executed in the order they are defined here

@test("security")
def _():
    assert_running("setup-secrets")
    # Unused secrets should be inaccessible
    succeed('[[ $(stat -c "%U:%G %a" /secrets/dummy) = "root:root 440" ]]')

    if "secure-node" in enabled_tests:
        machine.wait_for_unit("bitcoind")
        # `systemctl status` run by unprivileged users shouldn't leak cgroup info
        assert_matches(
            "runuser -u electrs -- systemctl status bitcoind 2>&1 >/dev/null",
            "Failed to dump process list for 'bitcoind.service', ignoring: Access denied",
        )
        # The 'operator' with group 'proc' has full access
        assert_full_match("runuser -u operator -- systemctl status bitcoind 2>&1 >/dev/null", "")

@test("bitcoind")
def _():
    assert_running("bitcoind")
    machine.wait_until_succeeds("bitcoin-cli getnetworkinfo")
    assert_matches("runuser -u operator -- bitcoin-cli getnetworkinfo | jq", '"version"')

    regtest = "regtest/" if "regtest" in enabled_tests else ""
    assert_full_match(f"stat  -c '%a' /var/lib/bitcoind/{regtest}.cookie", "640\n")

    # RPC access for user 'public' should be restricted
    machine.fail(
        "bitcoin-cli -rpcuser=public -rpcpassword=$(cat /secrets/bitcoin-rpcpassword-public) stop"
    )
    machine.wait_until_succeeds(
        log_has_string("bitcoind", "RPC User public not allowed to call method stop")
    )

@test("electrs")
def _():
    assert_running("electrs")
    wait_for_open_port(ip("electrs"), 4224)  # prometeus metrics provider
    # Check RPC connection to bitcoind
    if not "regtest" in enabled_tests:
        machine.wait_until_succeeds(
            log_has_string("electrs", "waiting for 0 blocks to download")
        )

@test("fulcrum")
def _():
    assert_running("fulcrum")
    machine.wait_until_succeeds(log_has_string("fulcrum", "started ok"))

# Impure: Stops electrs
# Stop electrs from spamming the test log with 'waiting for 0 blocks to download' messages
@test("stop-electrs")
def _():
    succeed("systemctl stop electrs")

@test("liquidd")
def _():
    assert_running("liquidd")
    machine.wait_until_succeeds("elements-cli getnetworkinfo")
    assert_matches("runuser -u operator -- elements-cli getnetworkinfo | jq", '"version"')
    succeed("runuser -u operator -- liquidswap-cli --help")

@test("clightning")
def _():
    assert_running("clightning")
    assert_matches("runuser -u operator -- lightning-cli getinfo | jq", '"id"')

    enabled_plugins = test_data["clightning-plugins"]
    if enabled_plugins:
        plugin_list = succeed("lightning-cli plugin list")
        plugins = json.loads(plugin_list)["plugins"]
        active = set(plugin["name"] for plugin in plugins if plugin["active"])
        failed = set(enabled_plugins).difference(active)
        if failed:
            raise Exception(
                f"The following clightning plugins are inactive:\n{failed}.\n\n"
                f"Output of 'lightning-cli plugin list':\n{plugin_list}"
            )
        active = [os.path.splitext(os.path.basename(p))[0] for p in enabled_plugins]
        machine.log("\n".join(["Active clightning plugins:", *active]))

        if "feeadjuster" in active:
            # This is a one-shot service, so this command only succeeds if the service succeeds
            succeed("systemctl start clightning-feeadjuster")

    if test_data["clightning-replication"]:
        replica_db = "/var/cache/clightning-replication/plaintext/lightningd.sqlite3"
        succeed(f"runuser -u clightning -- ls {replica_db}")
        # No other user should be able to read the unencrypted files
        machine.fail(f"runuser -u bitcoin -- ls {replica_db}")
        # A gocryptfs has been created
        succeed("ls /var/backup/clightning/lightningd-db/gocryptfs.conf")

@test("lnd")
def _():
    assert_running("lnd")
    assert_matches("runuser -u operator -- lncli getinfo | jq", '"version"')
    assert_no_failure("lnd")

    # Test certificate generation
    cert_alt_names = succeed("</secrets/lnd-cert openssl x509 -noout -ext subjectAltName")
    assert_str_matches(cert_alt_names, '10.0.0.1')
    assert_str_matches(cert_alt_names, '20.0.0.1')
    assert_str_matches(cert_alt_names, 'example.com')

@test("lndconnect-onion-lnd")
def _():
    assert_running("lnd")
    assert_matches("runuser -u operator -- lndconnect --url", ".onion")

@test("lndconnect-onion-clightning")
def _():
    assert_running("clightning-rest")
    assert_matches("runuser -u operator -- lndconnect-clightning --url", ".onion")

@test("lightning-loop")
def _():
    assert_running("lightning-loop")
    assert_matches("runuser -u operator -- loop --version", "version")
    # Check that lightning-loop fails with the right error, making sure
    # lightning-loop can connect to lnd
    machine.wait_until_succeeds(
        log_has_string(
            "lightning-loop",
            "Waiting for lnd to be fully synced to its chain backend, this might take a while",
        )
    )

@test("lightning-pool")
def _():
    assert_running("lightning-pool")
    assert_matches("su operator -c 'pool --version'", "version")
    # Check that lightning-pool fails with the right error, making sure
    # lightning-pool can connect to lnd
    machine.wait_until_succeeds(
        log_has_string(
            "lightning-pool",
            "Waiting for lnd to be fully synced to its chain backend, this might take a while",
        )
    )

@test("charge-lnd")
def _():
    # charge-lnd is a oneshot service that is started by a timer under regular operation
    succeed("systemctl start charge-lnd")
    assert_no_failure("charge-lnd")

@test("btcpayserver")
def _():
    assert_running("nbxplorer")
    machine.wait_until_succeeds(log_has_string("nbxplorer", "BTC: RPC connection successful"))
    if test_data["btcpayserver-lbtc"]:
        machine.wait_until_succeeds(log_has_string("nbxplorer", "LBTC: RPC connection successful"))
    wait_for_open_port(ip("nbxplorer"), 24444)

    assert_running("btcpayserver")
    machine.wait_until_succeeds(log_has_string("btcpayserver", "Now listening on"))
    wait_for_open_port(ip("btcpayserver"), 23000)
    # test lnd custom macaroon
    assert_matches(
        "runuser -u btcpayserver -- curl -fsS --cacert /secrets/lnd-cert "
        '--header "Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /run/lnd/btcpayserver.macaroon)" '
        f"-X GET https://{ip('lnd')}:8080/v1/getinfo | jq",
        '"version"',
    )
    # Test web server response
    assert_matches(f"curl -fsS -L {ip('btcpayserver')}:23000", "Welcome to your BTCPay&#xA0;Server")

@test("rtl")
def _():
    assert_running("rtl")
    machine.wait_until_succeeds(
        log_has_string("rtl", "Server is up and running")
    )

@test("clightning-rest")
def _():
    assert_running("clightning-rest")
    machine.wait_until_succeeds(
        log_has_string("clightning-rest", "cl-rest api server is ready and listening")
    )

@test("mempool")
def _():
    assert_running("mempool")
    assert_running("nginx")
    machine.wait_until_succeeds(
        log_has_string("mempool", "Mempool Server is running on port 8999")
    )
    assert_matches(f"curl -L {ip('nginx')}:60845", "mempool - Bitcoin Explorer")

@test("joinmarket")
def _():
    assert_running("joinmarket")
    machine.wait_until_succeeds(
        log_has_string("joinmarket", "JMDaemonServerProtocolFactory starting on 27183")
    )

@test("joinmarket-yieldgenerator")
def _():
    if "regtest" in enabled_tests:
        expected_log_msg = "You do not have the minimum required amount of coins to be a maker"
    else:
        expected_log_msg = "Critical error updating blockheight."

    machine.wait_until_succeeds(log_has_string("joinmarket-yieldgenerator", expected_log_msg))

@test("joinmarket-ob-watcher")
def _():
    assert_running("joinmarket-ob-watcher")
    machine.wait_until_succeeds(log_has_string("joinmarket-ob-watcher", "Starting ob-watcher"))

@test("nodeinfo")
def _():
    status, _ = machine.execute("systemctl is-enabled --quiet onion-addresses 2> /dev/null")
    if status == 0:
        machine.wait_for_unit("onion-addresses")
    json_info = succeed("runuser -u operator -- nodeinfo")
    info = json.loads(json_info)
    assert info["bitcoind"]["local_address"]

@test("secure-node")
def _():
    assert_running("onion-addresses")

# Run this test before the following tests that shut down services
# (and their corresponding network namespaces).
@test("netns-isolation")
def _():
    def get_ips(services):
        enabled = enabled_tests.intersection(services)
        return " ".join(ip(service) for service in enabled)

    def assert_reachable(src, dests):
        dest_ips = get_ips(dests)
        if src in enabled_tests and dest_ips:
            machine.succeed(f"ip netns exec nb-{src} fping -c1 -t100 {dest_ips}")

    def assert_unreachable(src, dests):
        dest_ips = get_ips(dests)
        if src in enabled_tests and dest_ips:
            machine.fail(
                # This fails when no host is reachable within 100 ms
                f"ip netns exec nb-{src} fping -c1 -t100 --reachable=1 {dest_ips}"
            )

    # These reachability tests are non-exhaustive
    assert_reachable("bitcoind", ["clightning", "lnd", "liquidd"])
    assert_unreachable("bitcoind", ["btcpayserver", "rtl", "lightning-loop"])
    assert_unreachable("btcpayserver", ["bitcoind", "lightning-loop"])

    # netns addresses can not be bound to in the main netns.
    # This prevents processes in the main netns from impersonating nix-bitcoin services.
    assert_matches(
        f"nc -l {ip('bitcoind')} 1080 2>&1 || true", "nc: Cannot assign requested address"
    )

    if "joinmarket" in enabled_tests:
        # netns-exec should drop capabilities
        assert_matches(
            "runuser -u operator -- netns-exec nb-joinmarket capsh --print | grep Current",
            re.compile("^Current: =$", re.MULTILINE),
        )

    if "clightning" in enabled_tests:
        # netns-exec should fail for unauthorized namespaces
        machine.fail("netns-exec nb-clightning ip a")

        # netns-exec should only be executable by the operator user
        machine.fail("runuser -u clightning -- netns-exec nb-bitcoind ip a")


# Impure: stops bitcoind (and dependent services)
@test("backups")
def _():
    # For testing that bitcoind wallets are backed up
    succeed("bitcoin-cli -named createwallet wallet_name=test blank=true >/dev/null")

    succeed("systemctl stop bitcoind")
    assert_matches("systemctl show -p ExecMainStatus --value bitcoind", "^0$")
    succeed("systemctl start duplicity")
    machine.wait_until_succeeds(log_has_string("duplicity", "duplicity.service: Deactivated successfully."))
    run_duplicity = "export $(cat /secrets/backup-encryption-env); duplicity"
    # Files in backup and /var/lib should be identical
    assert_matches(
        f"{run_duplicity} verify --archive-dir /var/lib/duplicity file:///var/lib/localBackups /var/lib",
        "no sync needed",
    )
    # Backup should include important files
    files = {
        "bitcoind": "var/lib/bitcoind/test/wallet.dat",
        "clightning": "var/lib/clightning/bitcoin/hsm_secret",
        "lnd": "var/lib/lnd/lnd-seed-mnemonic",
        "joinmarket": "var/lib/joinmarket/jm-wallet-seed",
        "btcpayserver": "var/backup/postgresql/btcpaydb.sql.gz",
    }
    actual_files = succeed(f"{run_duplicity} list-current-files file:///var/lib/localBackups")

    def assert_file_exists(file):
        if file not in actual_files:
            raise Exception(f"Backup file '{file}' is missing.")

    for test, file in files.items():
        if test in enabled_tests:
            assert_file_exists(file)

    assert_file_exists("secrets/lnd-wallet-password")

# Impure: restarts services
@test("restart-bitcoind")
def _():
    # Sanity-check system by restarting bitcoind.
    # This also restarts all services depending on bitcoind.
    succeed("systemctl restart bitcoind")

@test("regtest")
def _():
    def enabled(unit):
        if unit in enabled_tests:
            # Wait because the unit might have been restarted in the preceding
            # 'restart-bitcoind' test
            machine.wait_for_unit(unit)
            return True
        else:
            return False

    def get_block_height(ip, port):
        return (
            """echo '{"method": "blockchain.headers.subscribe", "id": 0}'"""
            f" | nc {ip} {port} | head -1 | jq -M .result.height"
        )

    num_blocks = test_data["num_blocks"]

    if enabled("electrs"):
        machine.wait_until_succeeds(log_has_string("electrs", "serving Electrum RPC"))
        assert_full_match(get_block_height(ip('electrs'), 50001), f"{num_blocks}\n")

    if enabled("fulcrum"):
        machine.wait_until_succeeds(log_has_string("fulcrum", "listening for connections"))
        assert_full_match(get_block_height(ip('fulcrum'), 50002), f"{num_blocks}\n")

    if enabled("clightning"):
        machine.wait_until_succeeds(
            f"[[ $(runuser -u operator -- lightning-cli getinfo | jq -M .blockheight) == {num_blocks} ]]"
        )

    if enabled("lnd"):
        machine.wait_until_succeeds(
            f"[[ $(runuser -u operator -- lncli getinfo | jq -M .block_height) == {num_blocks} ]]"
        )

    if enabled("lightning-loop"):
        machine.wait_until_succeeds(
            log_has_string("lightning-loop", f"Starting event loop at height {num_blocks}")
        )
        succeed("runuser -u operator -- loop getparams")

    if enabled("lightning-pool"):
        machine.wait_until_succeeds(
            log_has_string("lightning-pool", "lnd is now fully synced to its chain backend")
        )
        succeed("runuser -u operator -- pool orders list")

    if enabled("btcpayserver"):
        machine.wait_until_succeeds(log_has_string("nbxplorer", f"At height: {num_blocks}"))

    if enabled("mempool"):
        assert_running("nginx")
        assert_full_match(
            f"curl -fsS http://{ip('nginx')}:60845/api/v1/blocks/tip/height", str(num_blocks)
        )

@test("trustedcoin")
def _():
    def expect_clightning_log(str):
        machine.wait_until_succeeds(log_has_string("clightning", str))

    expect_clightning_log("plugin-trustedcoin[^^]\[0m\s+bitcoind RPC working")
    expect_clightning_log("plugin-trustedcoin[^^]\[0m\s+estimatefees error: none of the esploras returned usable responses")
    if "regtest" in enabled_tests:
        num_blocks = test_data["num_blocks"]
        expect_clightning_log(f"plugin-trustedcoin[^^]\[0m\s+returning block {num_blocks}")


if "netns-isolation" in enabled_tests:
    def ip(name):
        return test_data["netns"][name]["address"]
else:
    def ip(_):
        return "127.0.0.1"
