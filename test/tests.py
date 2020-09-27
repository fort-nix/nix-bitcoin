is_interactive = "is_interactive" in vars()


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
    machine.wait_for_unit(unit)
    assert_no_failure(unit)


def wait_for_open_port(address, port):
    def is_port_open(_):
        status, _ = machine.execute(f"nc -z {address} {port}")
        return status == 0

    with log.nested(f"Waiting for TCP port {address}:{port}"):
        retry(is_port_open)


def run_tests():
    # Don't execute the following test suite when this script is running in interactive mode
    if is_interactive:
        raise Exception()

    test_security()

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

    assert_running("electrs")
    wait_for_open_port(ip("electrs"), 4224)  # prometeus metrics provider
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

    assert_running("spark-wallet")
    wait_for_open_port(ip("spark-wallet"), 9737)
    spark_auth = re.search("login=(.*)", succeed("cat /secrets/spark-wallet-login"))[1]
    assert_matches(f"curl -s {spark_auth}@{ip('spark-wallet')}:9737", "Spark")

    assert_running("lightning-charge")
    wait_for_open_port(ip("lightning-charge"), 9112)
    machine.wait_until_succeeds(f"nc -z {ip('lightning-charge')} 9112")
    charge_auth = re.search("API_TOKEN=(.*)", succeed("cat /secrets/lightning-charge-env"))[1]
    assert_matches(
        f"curl -s api-token:{charge_auth}@{ip('lightning-charge')}:9112/info | jq", '"id"'
    )

    assert_running("nanopos")
    wait_for_open_port(ip("nanopos"), 9116)
    assert_matches(f"curl {ip('nanopos')}:9116", "tshirt")

    assert_running("onion-chef")

    assert_running("joinmarket")
    machine.wait_until_succeeds(
        log_has_string("joinmarket", "P2EPDaemonServerProtocolFactory starting on 27184")
    )
    machine.wait_until_succeeds(
        log_has_string("joinmarket-yieldgenerator", "Failure to get blockheight",)
    )

    # FIXME: use 'wait_for_unit' because 'create-web-index' always fails during startup due
    # to incomplete unit dependencies.
    # 'create-web-index' implicitly tests 'nodeinfo'.
    machine.wait_for_unit("create-web-index")
    assert_running("nginx")
    wait_for_open_port(ip("nginx"), 80)
    assert_matches(f"curl {ip('nginx')}", "nix-bitcoin")
    assert_matches(f"curl -L {ip('nginx')}/store", "tshirt")

    machine.wait_until_succeeds(log_has_string("bitcoind-import-banlist", "Importing node banlist"))
    assert_no_failure("bitcoind-import-banlist")

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

    prestop()

    ### Test duplicity

    succeed("systemctl stop bitcoind")
    succeed("systemctl start duplicity")
    machine.wait_until_succeeds(log_has_string("duplicity", "duplicity.service: Succeeded."))
    # Make sure files in duplicity backup and /var/lib are identical
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity verify '--archive-dir' '/var/lib/duplicity' 'file:///var/lib/localBackups' '/var/lib'",
        "0 differences found",
    )
    # Make sure duplicity backup includes important files
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity list-current-files 'file:///var/lib/localBackups'",
        "var/lib/clightning/bitcoin/hsm_secret",
    )
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity list-current-files 'file:///var/lib/localBackups'",
        "secrets/lnd-seed-mnemonic",
    )
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity list-current-files 'file:///var/lib/localBackups'",
        "secrets/jm-wallet-seed",
    )
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity list-current-files 'file:///var/lib/localBackups'",
        "var/lib/bitcoind/wallet.dat",
    )
    assert_matches(
        "export $(cat /secrets/backup-encryption-env); duplicity list-current-files 'file:///var/lib/localBackups'",
        "var/backup/postgresql/btcpaydb.sql.gz",
    )


def test_security():
    assert_running("setup-secrets")
    # Unused secrets should be inaccessible
    succeed('[[ $(stat -c "%U:%G %a" /secrets/dummy) = "root:root 440" ]]')

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


def ip(_):
    return "127.0.0.1"
