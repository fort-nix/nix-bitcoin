# Security Policy

## Reporting a Vulnerability

To report security issues send an encrypted email to the following nix-bitcoin developers or contact them via [matrix](https://matrix.org/).

| Name          | GPG Fingerprint                                    | Email                   | Matrix                                                                             |
|---------------|----------------------------------------------------|-------------------------|------------------------------------------------------------------------------------|
| Jonas Nick    | 36C7 1A37 C9D9 88BD E825  08D9 B1A7 0E4F 8DCD 0366 | jonasd.nick@gmail.com   | [@nickler:nixbitcoin.org](https://matrix.to/#/@nickler:nixbitcoin.org)             |
| Erik Arvstedt | 4E28 0A8C 1B33 4C86 C26B  C134 3331 2B94 4DD9 7846 | erik.arvstedt@gmail.com | [@erikarvstedt:matrix.org](https://matrix.to/#/@erikarvstedt:matrix.org)           |
| nixbitcoindev | 577A 3452 7F3E 2A85 E80F  E164 DD11 F9AD 5308 B3BA | nixbitcoin@i2pmail.org  | [@nixbitcoindev:nixbitcoin.org](https://matrix.to/#/@nixbitcoindev:nixbitcoin.org) |

You can import a GPG key by running the following command with that individual’s fingerprint: `gpg --keyserver hkps://keys.openpgp.org --recv-keys "<fingerprint>"`. Ensure that you put quotes around fingerprints containing spaces.

[Responsible disclosures](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure) may qualify for a reward from the nix-bitcoin security fund (see [below](#nix-bitcoin-security-fund)).

## Wall of Fame

*empty*


## nix-bitcoin security fund

The nix-bitcoin security fund rewards security researchers who discover and
report vulnerabilities in nix-bitcoin or its upstream dependencies.\
It is held on a 2 of 3 bitcoin multisig address and is open for donations:
```
bc1qrpnz05n0yznaj6yw82wy8dhwuqz86s87vdlhq4cu92fus9qal25s555wsy
```
([View balance](https://mempool.nixbitcoin.org/address/bc1qrpnz05n0yznaj6yw82wy8dhwuqz86s87vdlhq4cu92fus9qal25s555wsy))


Rewards are paid out as percentages of the total fund, rather than as fixed
amounts.

The nix-bitcoin developers [listed above](#reporting-a-vulnerability) each hold
one key to the multisig address and collectively form the nix-bitcoin developer
quorum.

### Eligible Vulnerabilities

The following types of vulnerabilities qualify for rewards, to the exclusion of
all other security vulnerabilities.

| Type | Description | Examples |
| :-: | :-: | :-: |
| Outright Vulnerabilities | Vulnerabilities in nix-bitcoin specific tooling (except CI tooling) | privilege escalation in SUID binary `netns-exec`, improper release signature verification through `fetch-release` |
| Violations of [PoLP](https://en.wikipedia.org/wiki/Principle_of_least_privilege) | nix-bitcoin services are given too much privilege over the system or unnecessary access to other nix-bitcoin services, or one of the nix-bitcoin isolation measures is incorrectly implemented | `netns-isolation` doesn't work, RTL has access to bitcoin RPC interface or files |
| Vulnerabilities in Dependencies | A vulnerability in any dependency of a nix-bitcoin installation with a configuration consisting of any combination of the following services: bitcoind, clightning, lnd, electrs, joinmarket, btcpayserver, liquidd.<br />**Note:** The vulnerability must first be reported to and handled by the maintainers of the dependency before it qualifies for a reward| Compromised NixOS expression pulls in malicious package, JoinMarket pulls in a python dependency with a known severe vulnerability |
| Bad Documentation | Our documentation suggests blatantly insecure things | `install.md` tells you to add our SSH keys to your root user |
| Compromise of Signing Key | Compromise of the nix-bitcoin signing key, i.e., `0xB1A70E4F8DCD0366` | Leaking the key, managing to sign something with it |

### Reward

Researchers qualify for a maximum reward[^1] of 10% of the total fund holdings for
reporting any vulnerability that matches the above eligibility requirements. If
a vulnerability or any combination of a number of vulnerabilities that meet the
above-described eligibility requirements can lead to a realistic attack on
nix-bitcoin users, researchers qualify for a higher maximum reward[^1] depending
the final outcome of the attack scenario:

| Outcome | Description | Maximum Reward of Total Fund[^1] |
| :-: | :-: | :-: |
| Loss of Funds | Attack allows stealing or destroying user's funds | 50 % |
| Loss of Privacy | Attack allows exfiltrating sensitive information or otherwise attributing a user's real world identity to his nix-bitcoin node or funds held/managed thereon without the user specifically opting-in to this (e.g., by disabling the `secure-node` preset) | 25 % |
| Denial of Service | Attack allows crashing a service or otherwise denying a user service from his node | 25 % |

All other reported vulnerabilities which meet the above requirements without a
clear and plausible attack scenario receive a maximum reward[^1] of 10% of the
fund.

[^1]: Rewards are subject to a discount at the discretion of the nix-bitcoin
developer quorum for reasons such as insignificance of the vulnerability or
obscurity of the victim's required configuration, as well as simple mitigation
(i.e.  the attack should have been mitigated anyway by common-sense security
measures) or complex/unlikely attack execution.

### Policy

* Vulnerabilities must be [responsibly
  disclosed](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure).
* E2EE: Vulnerabilities must be disclosed via end-to-end encrypted communication
  methods, such as PGP E-Mail or Matrix.
* Wall of Fame: In addition to the above rewards, security researchers will also
  be added to the Wall of Fame, unless, of course, they wish to remain
  anonymous.
* First come, first serve: Rewards are awarded strictly on a first come, first
  serve basis from the date they were responsibly disclosed in their entirety.
  Multiple reports from the same researcher can either be bundled for a higher
  likelihood of receiving the full maximum reward or rewarded individually,
  proportional to the remaining amount.
* Exclusion of dependencies with existing bug bounty programms: Software which
  is covered by an existing bug bounty program is not eligible for rewards under
  the "Vulnerabilities in Dependencies" category.
* Exclusion of dependencies with known vulnerabilities that are in the process
  of being patched: Software with a known vulnerability where there is reason to
  believe that the patch is still under development or simply has not yet been
  ported to NixOS, due to the relative recency of the patch, is not eligible for
  rewards under the "Vulnerabilities in Dependencies" category.
* Termination: The fund can be terminated at any time by the quorum of key
  holders in which case the holdings are donated to non-profit organizations.
* This document may be updated over time to ensure smooth and purposeful
  operation of the fund as an incentive for security researchers to investigate
  and report vulnerabilities in the nix-bitcoin ecosystem.
