run_tests()

## electrs
# the main test body stops electrs
succeed("systemctl start electrs")
machine.wait_for_open_port(4224)  # prometeus metrics provider

## spark-wallet
machine.wait_for_open_port(9737)
spark_auth = re.search("login=(.*)", succeed("cat /secrets/spark-wallet-login"))[1]
assert_matches(f"curl -s {spark_auth}@localhost:9737", "Spark")

## lightning-charge
machine.wait_for_open_port(9112)
charge_auth = re.search("API_TOKEN=(.*)", succeed("cat /secrets/lightning-charge-env"))[1]
assert_matches(f"curl -s api-token:{charge_auth}@localhost:9112/info | jq", '"id"')

## nanopos
machine.wait_for_open_port(9116)
assert_matches("curl localhost:9116", "tshirt")

## web index
machine.wait_for_open_port(80)
assert_matches("curl localhost", "nix-bitcoin")
assert_matches("curl -L localhost/store", "tshirt")
