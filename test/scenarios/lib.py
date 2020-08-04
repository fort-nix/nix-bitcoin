def succeed(*cmds):
    """Returns the concatenated output of all cmds"""
    return machine.succeed(*cmds)


def assert_matches(cmd, regexp):
    out = succeed(cmd)
    if not re.search(regexp, out):
        raise Exception(f"Pattern '{regexp}' not found in '{out}'")


def assert_matches_exactly(cmd, regexp):
    out = succeed(cmd)
    if not re.fullmatch(regexp, out):
        raise Exception(f"Pattern '{regexp}' doesn't match '{out}'")


def log_has_string(unit, str):
    return f"journalctl -b --output=cat -u {unit} --grep='{str}'"


def assert_no_failure(unit):
    """Unit should not have failed since the system is running"""
    machine.fail(log_has_string(unit, "Failed with result"))


def assert_running(unit):
    machine.wait_for_unit(unit)
    assert_no_failure(unit)


# Don't execute the following test suite when this script is running in interactive mode
if "is_interactive" in vars():
    raise Exception()

### Tests

# The argument extra_tests is a dictionary from strings to functions. The string
# determines at which point of run_tests the corresponding function is executed.
def run_tests(extra_tests):
    assert_running("setup-secrets")
    # Unused secrets should be inaccessible
    succeed('[[ $(stat -c "%U:%G %a" /secrets/dummy) = "root:root 440" ]]')

    assert_running("bitcoind")
    machine.wait_until_succeeds("bitcoin-cli getnetworkinfo")
    assert_matches("su operator -c 'bitcoin-cli getnetworkinfo' | jq", '"version"')
    # Test RPC Whitelist
    machine.wait_until_succeeds("su operator -c 'bitcoin-cli help'")
    # Restating rpcuser & rpcpassword overrides privileged credentials
    machine.fail(
        "bitcoin-cli -rpcuser=publicrpc -rpcpassword=$(cat /secrets/bitcoin-rpcpassword-public) help"
    )
    machine.wait_until_succeeds(
        log_has_string("bitcoind", "RPC User publicrpc not allowed to call method help")
    )

    assert_running("electrs")
    extra_tests.pop("electrs")()
    # Check RPC connection to bitcoind
    machine.wait_until_succeeds(log_has_string("electrs", "NetworkInfo"))
    # Stop electrs from spamming the test log with 'wait for bitcoind sync' messages
    succeed("systemctl stop electrs")

    assert_running("liquidd")
    machine.wait_until_succeeds("elements-cli getnetworkinfo")
    assert_matches("su operator -c 'elements-cli getnetworkinfo' | jq", '"version"')
    succeed("su operator -c 'liquidswap-cli --help'")

    assert_running("clightning")
    assert_matches("su operator -c 'lightning-cli getinfo' | jq", '"id"')

    assert_running("lnd")
    assert_matches("su operator -c 'lncli getinfo' | jq", '"version"')
    assert_no_failure("lnd")

    succeed("systemctl start lightning-loop")
    assert_matches("su operator -c 'loop --version'", "version")
    # Check that lightning-loop fails with the right error, making sure
    # lightning-loop can connect to lnd
    machine.wait_until_succeeds(
        log_has_string("lightning-loop", "chain notifier RPC isstill in the process of starting")
    )

    assert_running("spark-wallet")
    extra_tests.pop("spark-wallet")()

    assert_running("lightning-charge")
    extra_tests.pop("lightning-charge")()

    assert_running("nanopos")
    extra_tests.pop("nanopos")()

    assert_running("onion-chef")

    # FIXME: use 'wait_for_unit' because 'create-web-index' always fails during startup due
    # to incomplete unit dependencies.
    # 'create-web-index' implicitly tests 'nodeinfo'.
    machine.wait_for_unit("create-web-index")
    assert_running("nginx")
    extra_tests.pop("web-index")()

    machine.wait_until_succeeds(log_has_string("bitcoind-import-banlist", "Importing node banlist"))
    assert_no_failure("bitcoind-import-banlist")

    # test that `systemctl status` can't leak credentials
    assert_matches(
        "sudo -u electrs systemctl status clightning 2>&1 >/dev/null",
        "Failed to dump process list for 'clightning.service', ignoring: Access denied",
    )
    machine.succeed("grep -Fq hidepid=2 /proc/mounts")

    ### Additional tests

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

    extra_tests.pop("final")()

    ### Check that all extra_tests have been run
    assert len(extra_tests) == 0
