- **Q:** The clightning service is running but when I try to use it (f.e. by running
  `lightning-cli getinfo` as user operator) all I get is `lightning-cli: Connecting
  to 'lightning-rpc': Connection refused`.\
  **A:** Check your clightning logs with `journalctl -eu clightning`. Do you see
  something like `bitcoin-cli getblock ... false` failed? Are you using pruned mode?
  That means that clightning hasn't seen all the blocks it needs to and it can't get
  that block because your node is pruned. \
  If you're just setting up a new node you can `systemctl stop clightning` and wipe
  your `/var/lib/clightning` directory. Otherwise you need to reindex the Bitcoin
  node.

- **Q:** My disk space is getting low due to nix.\
  **A:** run `nix-collect-garbage -d`

- **Q:** Where is `sudo`?\
  **A:** After [CVE-2021-3156](https://www.openwall.com/lists/oss-security/2021/01/26/3),
  we've replaced `sudo` with OpenBSD's `doas` for users of the `secure-node.nix` template.
  It has greatly reduced complexity and is therefore less likely to be a source of
  severe vulnerabilities in the future.
