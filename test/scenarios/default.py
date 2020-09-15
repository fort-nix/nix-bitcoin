def electrs():
    machine.wait_for_open_port(4224)  # prometeus metrics provider


def nbxplorer():
    machine.wait_for_open_port(24444)


def btcpayserver():
    machine.wait_for_open_port(23000)
    # test lnd custom macaroon
    assert_matches(
        'sudo -u btcpayserver curl -s --cacert /secrets/lnd-cert --header "Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /run/lnd/btcpayserver.macaroon)" -X GET https://127.0.0.1:8080/v1/getinfo | jq',
        '"version"',
    )


def spark_wallet():
    machine.wait_for_open_port(9737)
    spark_auth = re.search("login=(.*)", succeed("cat /secrets/spark-wallet-login"))[1]
    assert_matches(f"curl -s {spark_auth}@localhost:9737", "Spark")


def lightning_charge():
    machine.wait_for_open_port(9112)
    charge_auth = re.search("API_TOKEN=(.*)", succeed("cat /secrets/lightning-charge-env"))[1]
    assert_matches(f"curl -s api-token:{charge_auth}@localhost:9112/info | jq", '"id"')


def nanopos():
    machine.wait_for_open_port(9116)
    assert_matches("curl localhost:9116", "tshirt")


def web_index():
    machine.wait_for_open_port(80)
    assert_matches("curl localhost", "nix-bitcoin")
    assert_matches("curl -L localhost/store", "tshirt")


def prestop():
    pass


extra_tests = {
    "electrs": electrs,
    "nbxplorer": nbxplorer,
    "btcpayserver": btcpayserver,
    "spark-wallet": spark_wallet,
    "lightning-charge": lightning_charge,
    "nanopos": nanopos,
    "web-index": web_index,
    "prestop": prestop,
}

run_tests(extra_tests)
