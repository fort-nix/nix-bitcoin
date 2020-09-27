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


# Impure: Stops electrs
@test("electrs")
def _():
    assert_running("electrs")
    wait_for_open_port(ip("electrs"), 4224)  # prometeus metrics provider
    # Check RPC connection to bitcoind
    machine.wait_until_succeeds(log_has_string("electrs", "NetworkInfo"))
    # Stop electrs from spamming the test log with 'wait for bitcoind sync' messages
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
        log_has_string("joinmarket", "P2EPDaemonServerProtocolFactory starting on 27184")
    )
    machine.wait_until_succeeds(
        log_has_string("joinmarket-yieldgenerator", "Failure to get blockheight",)
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
    ping_bitcoind = "ip netns exec nb-bitcoind ping -c 1 -w 1"
    ping_nanopos = "ip netns exec nb-nanopos ping -c 1 -w 1"
    ping_nbxplorer = "ip netns exec nb-nbxplorer ping -c 1 -w 1"

    # Positive ping tests (non-exhaustive)
    machine.succeed(
        "%s %s &&" % (ping_bitcoind, ip("bitcoind"))
        + "%s %s &&" % (ping_bitcoind, ip("clightning"))
        + "%s %s &&" % (ping_bitcoind, ip("lnd"))
        + "%s %s &&" % (ping_bitcoind, ip("liquidd"))
        + "%s %s &&" % (ping_bitcoind, ip("nbxplorer"))
        + "%s %s &&" % (ping_nbxplorer, ip("btcpayserver"))
        + "%s %s &&" % (ping_nanopos, ip("lightning-charge"))
        + "%s %s &&" % (ping_nanopos, ip("nanopos"))
        + "%s %s" % (ping_nanopos, ip("nginx"))
    )

    # Negative ping tests (non-exhaustive)
    machine.fail(
        "%s %s ||" % (ping_bitcoind, ip("spark-wallet"))
        + "%s %s ||" % (ping_bitcoind, ip("lightning-loop"))
        + "%s %s ||" % (ping_bitcoind, ip("lightning-charge"))
        + "%s %s ||" % (ping_bitcoind, ip("nanopos"))
        + "%s %s ||" % (ping_bitcoind, ip("recurring-donations"))
        + "%s %s ||" % (ping_bitcoind, ip("nginx"))
        + "%s %s ||" % (ping_nanopos, ip("bitcoind"))
        + "%s %s ||" % (ping_nanopos, ip("clightning"))
        + "%s %s ||" % (ping_nanopos, ip("lnd"))
        + "%s %s ||" % (ping_nanopos, ip("lightning-loop"))
        + "%s %s ||" % (ping_nanopos, ip("liquidd"))
        + "%s %s ||" % (ping_nanopos, ip("electrs"))
        + "%s %s ||" % (ping_nanopos, ip("spark-wallet"))
        + "%s %s ||" % (ping_nanopos, ip("recurring-donations"))
        + "%s %s" % (ping_nanopos, ip("btcpayserver"))
    )

    # test that netns-exec can't be run for unauthorized namespace
    machine.fail("netns-exec nb-electrs ip a")

    # test that netns-exec drops capabilities
    assert_full_match(
        "su operator -c 'netns-exec nb-bitcoind capsh --print | grep Current '", "Current: =\n"
    )

    # test that netns-exec can not be executed by users that are not operator
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


if "netns-isolation" in enabled_tests:
    netns_ips = {
        "bitcoind": "169.254.1.12",
        "clightning": "169.254.1.13",
        "lnd": "169.254.1.14",
        "liquidd": "169.254.1.15",
        "electrs": "169.254.1.16",
        "spark-wallet": "169.254.1.17",
        "lightning-charge": "169.254.1.18",
        "nanopos": "169.254.1.19",
        "recurring-donations": "169.254.1.20",
        "nginx": "169.254.1.21",
        "lightning-loop": "169.254.1.22",
        "nbxplorer": "169.254.1.23",
        "btcpayserver": "169.254.1.24",
    }

    def ip(netns):
        return netns_ips[netns]


else:

    def ip(_):
        return "127.0.0.1"
