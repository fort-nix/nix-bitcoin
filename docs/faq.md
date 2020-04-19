* **Q:** When deploying or trying to SSH into the machine I see
    ```
    bitcoin-node> waiting for SSH...
    Received disconnect from 10.1.1.200 port 22:2: Too many authentication failures
    ```
    * **A:** Somehow ssh-agent and nixops don't play well together. Try killing the ssh-agent.
* **Q:** When deploying or trying to SSH into the machine I see
    ```
    root@xxx.xxx.xxx.xxx: Permission denied (publickey,password,keyboard-interactive).
    ```
    Make sure you don't have something like
    ```
    Host *
        PubkeyAuthentication no
    ```
    in your ssh config.
* **Q:** When deploying to virtualbox for the first time I see
    ```
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: Started Get NixOps SSH Key.
    bitcoin-node> Mar 19 09:22:27 bitcoin-node get-vbox-nixops-client-key-start[2226]: VBoxControl: error: Failed to connect to the guest property service, error VERR_INTERNAL_ERROR
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Main process exited, code=exited, status=1/FAILURE
    bitcoin-node> Mar 19 09:22:27 bitcoin-node systemd[1]: get-vbox-nixops-client-key.service: Failed with result 'exit-code'.
    bitcoin-node> error: Traceback (most recent call last):
      File "/nix/store/6zyvpi0q6mvprycadz2dpdqag4742y18-python2.7-nixops-1.6pre0_abcdef/lib/python2.7/site-packages/nixops/deployment.py", line 731, in worker
        raise Exception("unable to activate new configuration")
    Exception: unable to activate new configuration
    ```
    * **A:** This is issue https://github.com/NixOS/nixops/issues/908. The machine needs to be rebooted. You can do that by running `nixops deploy` with the `--force-reboot` flag once.
* **Q:** I'm deploying to virtualbox it's not able to connect anymore.
    * **A:** Maybe the IP address of the box changed. Run `nixops deploy --check` to update nixops with the new IP address. Sometimes you need to run `nixops modify -d <deployment> network/network.nix network/network-vbox.nix`. Sometimes you also need to remove the old IP address from `~/.ssh/known_hosts`.
* **Q:** The clightning service is running but when I try to use it (f.e. by running `lightning-cli getinfo` as user operator) all I get is `lightning-cli: Connecting to 'lightning-rpc': Connection refused`.
    * **A:** Check your clightning logs with `journalctl -eu clightning`. Do you see something like `bitcoin-cli getblock ... false` failed? Are you using pruned mode? That means that clightning hasn't seen all the blocks it needs to and it can't get that block because your node is pruned. If you're just setting up a new node you can `systemctl stop clightning` and wipe your `/var/lib/clightning` directory. Otherwise you need to reindex the Bitcoin node.
* **Q:** My disk space is getting low due to nix.
    * **A:** run `nix-collect-garbage -d`
* **Q:** `nix-shell` takes too long and doesn't finish generating `/secrets`
    * **A:** This might be the result of low system entropy. Check your entropy with `cat /proc/sys/kernel/random/entropy_avail`. If necessary, take steps to increase entropy like performing some tasks on the system or acquiring a hardware true random number generator.
