from collections import OrderedDict


def succeed(*cmds):
    """Returns the concatenated output of all cmds"""
    return machine.succeed(*cmds)


def assert_matches(cmd, regexp):
    out = succeed(cmd)
    if not re.search(regexp, out):
        raise Exception(f"Pattern '{regexp}' not found in '{out}'")


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

    with log.nested(f"Waiting for TCP port {address}:{port}"):
        retry(is_port_open)


### Test runner

tests = OrderedDict()


def test(name):
    def x(fn):
        tests[name] = fn

    return x


def run_tests():
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
        with log.nested(f"test: {test}"):
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
        # Access to '/proc' should be restricted
        machine.succeed("grep -Fq hidepid=2 /proc/mounts")

        machine.wait_for_unit("bitcoind")
        # `systemctl status` run by unprivileged users shouldn't leak cgroup info
        assert_matches(
            "sudo -u electrs systemctl status bitcoind 2>&1 >/dev/null",
            "Failed to dump process list for 'bitcoind.service', ignoring: Access denied",
        )
        # The 'operator' with group 'proc' has full access
        assert_full_match("sudo -u operator systemctl status bitcoind 2>&1 >/dev/null", "")


@test("bitcoind")
def _():
    assert_running("bitcoind")
    machine.wait_until_succeeds("bitcoin-cli getnetworkinfo")
    assert_matches("su operator -c 'bitcoin-cli getnetworkinfo' | jq", '"version"')
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
    machine.wait_until_succeeds(log_has_string("electrs", "NetworkInfo"))


# Impure: Stops electrs
# Stop electrs from spamming the test log with 'WARN - wait until IBD is over' messages
@test("stop-electrs")
def _():
    succeed("systemctl stop electrs")


@test("liquidd")
def _():
    assert_running("liquidd")
    machine.wait_until_succeeds("elements-cli getnetworkinfo")
    assert_matches("su operator -c 'elements-cli getnetworkinfo' | jq", '"version"')
    succeed("su operator -c 'liquidswap-cli --help'")


@test("clightning")
def _():
    assert_running("clightning")
    assert_matches("su operator -c 'lightning-cli getinfo' | jq", '"id"')


@test("lnd")
def _():
    assert_running("lnd")
    assert_matches("su operator -c 'lncli getinfo' | jq", '"version"')
    assert_no_failure("lnd")


@test("lightning-loop")
def _():
    assert_running("lightning-loop")
    assert_matches("su operator -c 'loop --version'", "version")
    # Check that lightning-loop fails with the right error, making sure
    # lightning-loop can connect to lnd
    machine.wait_until_succeeds(
        log_has_string(
            "lightning-loop",
            "Waiting for lnd to be fully synced to its chain backend, this might take a while",
        )
    )


@test("btcpayserver")
def _():
    assert_running("nbxplorer")
    machine.wait_until_succeeds(log_has_string("nbxplorer", "BTC: RPC connection successful"))
    wait_for_open_port(ip("nbxplorer"), 24444)
    assert_running("btcpayserver")
    machine.wait_until_succeeds(log_has_string("btcpayserver", "Listening on"))
    wait_for_open_port(ip("btcpayserver"), 23000)
    # test lnd custom macaroon
    assert_matches(
        "sudo -u btcpayserver curl -s --cacert /secrets/lnd-cert "
        '--header "Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /run/lnd/btcpayserver.macaroon)" '
        f"-X GET https://{ip('lnd')}:8080/v1/getinfo | jq",
        '"version"',
    )


@test("spark-wallet")
def _():
    assert_running("spark-wallet")
    wait_for_open_port(ip("spark-wallet"), 9737)
    spark_auth = re.search("login=(.*)", succeed("cat /secrets/spark-wallet-login"))[1]
    assert_matches(f"curl -s {spark_auth}@{ip('spark-wallet')}:9737", "Spark")


@test("lightning-charge")
def _():
    assert_running("lightning-charge")
    wait_for_open_port(ip("lightning-charge"), 9112)
    machine.wait_until_succeeds(f"nc -z {ip('lightning-charge')} 9112")
    charge_auth = re.search("API_TOKEN=(.*)", succeed("cat /secrets/lightning-charge-env"))[1]
    assert_matches(
        f"curl -s api-token:{charge_auth}@{ip('lightning-charge')}:9112/info | jq", '"id"'
    )


@test("nanopos")
def _():
    assert_running("nanopos")
    wait_for_open_port(ip("nanopos"), 9116)
    assert_matches(f"curl {ip('nanopos')}:9116", "tshirt")


@test("joinmarket")
def _():
    assert_running("joinmarket")
    machine.wait_until_succeeds(
        log_has_string("joinmarket", "JMDaemonServerProtocolFactory starting on 27183")
    )


@test("joinmarket-yieldgenerator")
def _():
    machine.wait_until_succeeds(
        log_has_string("joinmarket-yieldgenerator", "Critical error updating blockheight.",)
    )


@test("secure-node")
def _():
    assert_running("onion-chef")

    # FIXME: use 'wait_for_unit' because 'create-web-index' always fails during startup due
    # to incomplete unit dependencies.
    # 'create-web-index' implicitly tests 'nodeinfo'.
    machine.wait_for_unit("create-web-index")
    assert_running("nginx")
    wait_for_open_port(ip("nginx"), 80)
    assert_matches(f"curl {ip('nginx')}", "nix-bitcoin")
    assert_matches(f"curl -L {ip('nginx')}/store", "tshirt")


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
    assert_unreachable("bitcoind", ["btcpayserver", "spark-wallet", "lightning-loop"])
    assert_unreachable("btcpayserver", ["bitcoind", "lightning-loop", "liquidd"])

    # netns addresses can not be bound to in the main netns.
    # This prevents processes in the main netns from impersonating nix-bitcoin services.
    assert_matches(
        f"nc -l {ip('bitcoind')} 1080 2>&1 || true", "nc: Cannot assign requested address"
    )

    if "joinmarket" in enabled_tests:
        # netns-exec should drop capabilities
        assert_full_match(
            "su operator -c 'netns-exec nb-joinmarket capsh --print | grep Current'", "Current: =\n"
        )

    if "clightning" in enabled_tests:
        # netns-exec should fail for unauthorized namespaces
        machine.fail("netns-exec nb-clightning ip a")

        # netns-exec should only be executable by the operator user
        machine.fail("sudo -u clightning netns-exec nb-bitcoind ip a")


# Impure: stops bitcoind (and dependent services)
@test("backups")
def _():
    succeed("systemctl stop bitcoind")
    succeed("systemctl start duplicity")
    machine.wait_until_succeeds(log_has_string("duplicity", "duplicity.service: Succeeded."))
    run_duplicity = "export $(cat /secrets/backup-encryption-env); duplicity"
    # Files in backup and /var/lib should be identical
    assert_matches(
        f"{run_duplicity} verify --archive-dir /var/lib/duplicity file:///var/lib/localBackups /var/lib",
        "0 differences found",
    )
    # Backup should include important files
    files = succeed(f"{run_duplicity} list-current-files file:///var/lib/localBackups")
    assert "var/lib/clightning/bitcoin/hsm_secret" in files
    assert "secrets/lnd-seed-mnemonic" in files
    assert "secrets/jm-wallet-seed" in files
    assert "var/lib/bitcoind/wallet.dat" in files
    assert "var/backup/postgresql/btcpaydb.sql.gz" in files


# Impure: restarts services
@test("banlist-and-restart")
def _():
    machine.wait_until_succeeds(log_has_string("bitcoind-import-banlist", "Importing node banlist"))
    assert_no_failure("bitcoind-import-banlist")

    # Current time in µs
    pre_restart = succeed("date +%s.%6N").rstrip()

    # Sanity-check system by restarting all services
    succeed(
        "systemctl restart bitcoind clightning lnd lightning-loop spark-wallet lightning-charge nanopos liquidd"
    )

    # Now that the bitcoind restart triggered a banlist import restart, check that
    # re-importing already banned addresses works
    machine.wait_until_succeeds(
        log_has_string(f"bitcoind-import-banlist --since=@{pre_restart}", "Importing node banlist")
    )
    assert_no_failure("bitcoind-import-banlist")


@test("regtest")
def _():
    if "electrs" in enabled_tests:
        machine.wait_until_succeeds(log_has_string("electrs", "BlockchainInfo"))
        get_block_height_cmd = (
            """echo '{"method": "blockchain.headers.subscribe", "id": 0, "params": []}'"""
            f" | nc -N {ip('electrs')} 50001 | jq -M .result.height"
        )
        assert_full_match(get_block_height_cmd, "10\n")
    if "clightning" in enabled_tests:
        machine.wait_until_succeeds(
            "[[ $(sudo -u operator lightning-cli getinfo | jq -M .blockheight) == 10 ]]"
        )
    if "lnd" in enabled_tests:
        machine.wait_until_succeeds(
            "[[ $(sudo -u operator lncli getinfo | jq -M .block_height) == 10 ]]"
        )
    if "lightning-loop" in enabled_tests:
        machine.wait_until_succeeds(
            log_has_string("lightning-loop", "Starting event loop at height 10")
        )
        succeed("sudo -u operator loop getparams")


if "netns-isolation" in enabled_tests:

    def ip(name):
        return test_data["netns"][name]["address"]


else:

    def ip(_):
        return "127.0.0.1"
