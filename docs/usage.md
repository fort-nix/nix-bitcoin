Updating
---
Run `git pull` in the nix-bitcoin directory, enter the nix shell with `nix-shell` and redeploy with `nixops deploy -d bitcoin-node`.

## Verifying GPG Signatures (recommended)
1. Import jonasnick's gpg key

	```
	gpg2 --receive-key 36C71A37C9D988BDE82508D9B1A70E4F8DCD0366
	```

2. Trust jonasnick's gpg key
	
	```
	gpg2 --edit-key 36C71A37C9D988BDE82508D9B1A70E4F8DCD0366
	trust
	4
	quit
	```

3.  Verify commit after `git pull`

	```
	git verify-commit <hash of latest commit>
	```

Nodeinfo
---
Run `nodeinfo` to see your onion addresses for the webindex, spark, etc. if they are enabled.

Connect to spark-wallet
---
1. Enable spark-wallet in `configuration.nix`
	
	Change 
	```
	# services.spark-wallet.enable = true;
	```
	to 
	```
	services.spark-wallet.enable = true;
	```

2. Deploy new `configuration.nix`

	```
	nixops deploy -d bitcoin-node
	```

3. Get the onion address, access key and QR access code for the spark wallet android app

	```
	journalctl -eu spark-wallet
	```
	Note: The qr code might have issues scanning if you have a light terminal theme. Try setting it to dark or highlightning the entire output to invert the colors.

4. Connect to spark-wallet android app

	```
	Server Settings
	Scan QR
	Done
	```

Connect to electrs
---
1. Enable electrs in `configuration.nix`
	
	Change 
	```
	# services.electrs.enable = true;
	```
	to 
	```
	services.electrs.enable = true;
	```

2. Deploy new `configuration.nix`

	```
	nixops deploy -d bitcoin-node
	```

3. Get electrs onion address

	```
	nodeinfo | grep 'ELECTRS_ONION'
	```

4. Connect to electrs

	On electrum wallet laptop
	```
	electrum --oneserver --server=<ELECTRS_ONION>:50002:s
	```

	On electrum android phone
	```
	Three dots in the upper-right-hand corner
	Network
	Server > Enter <ELECTRS_ONION>
	Back
	Auto-connect: OFF
	One-server mode: ON
	```

Connect to nix-bitcoin node through ssh Tor Hidden Service
---
1. Run `nodeinfo` on your nix-bitcoin node and note the `SSHD_ONION`

	```
	nixops ssh operator@bitcoin-node
	nodeinfo | grep 'SSHD_ONION'
	```

2. Create a SSH key 

	```
	ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
	```

3. Place the ed25519 key's fingerprint in the `configuration.nix` `openssh.authorizedKeys.keys` field like so

	```
	# FIXME: Add your SSH pubkey
	services.openssh.enable = true;
	users.users.root = {
	  openssh.authorizedKeys.keys = [ "[contents of ~/.ssh/id_ed25519.pub]" ];
	};
	```

4. Connect to your nix-bitcoin node's ssh Tor Hidden Service, forwarding a local port to the nix-bitcoin node's ssh server

	```
	ssh -i ~/.ssh/id_ed25519 -L [random port of your choosing]:localhost:22 root@[your SSHD_ONION]
	```

5. Edit your `network-nixos.nix` to look like this

	```
	{
	  bitcoin-node =
	    { config, pkgs, ... }:
	    { deployment.targetHost = "127.0.0.1";
	    deployment.targetPort = [random port of your choosing];
	    };
	}
	```

6. Now you can run `nixops deploy -d bitcoin-node` and it will connect through the ssh tunnel you established in step iv. This also allows you to do more complex ssh setups that `nixops ssh` doesn't support. An example would be authenticating with [Trezor's ssh agent](https://github.com/romanz/trezor-agent), which provides extra security.

Initialize a Trezor for Bitcoin Core's Hardware Wallet Interface
---

1. Enable Trezor in `configuration.nix`

	Change
	```
	# services.hardware-wallets.trezor = true;
	```
	to
	```
	services.hardware-wallets.trezor = true;
	```

2. Deploy new `configuration.nix`

	```
	nixops deploy -d bitcoin-node
	```

3. Check that your nix-bitcoin node recognizes your Trezor

	```
	nixops ssh operator@bitcoin-node
	lsusb
	```
	Should show something relating to your Trezor

4. If your Trezor has outdated firmware or is not yet initialized: Start your Trezor in bootloader mode

	Trezor v1
	```
	Plug in your Trezor with both buttons depressed
	```

	Trezor v2
	```
	Start swiping your finger across your Trezor's touchscreen and plug in the USB cable when your finger is halfway through
	```

5. If your Trezor's firmware is outdated: Update your Trezor's firmware

	```
	trezorctl firmware-update
	```
	Follow the on-screen instructions

	**Caution: This command _will_ wipe your Trezor. If you already store Bitcoin on it, only do this with the recovery seed nearby.**

6. If your Trezor is not yet initialized: Set up your Trezor

	```
	trezorctl reset-device -p
	```
	Follow the on-screen instructions

7. Find your Trezor

	```
	hwi enumerate
	hwi -t trezor -d <path from previous command> promptpin
	hwi -t trezor -d <path> sendpin <number positions for the PIN as displayed on your device's screen>
	hwi enumerate
	```

8. Follow Bitcoin Core's instructions on [Using Bitcoin Core with Hardware Wallets](https://github.com/bitcoin-core/HWI/blob/master/docs/bitcoin-core-usage.md) to use your Trezor with `bitcoin-cli` on your nix-bitcoin node
