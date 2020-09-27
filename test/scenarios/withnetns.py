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


def prestop():
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


run_tests()
