nix-bitcoin
===

Nix packages and nixos modules including profiles to easily install featureful Bitcoin nodes.
Work in progress.

Profiles
---
`nixbitcoin.nix` provides the two profiles "minimal" and "all":

* minimal
    * bitcoind (pruned) with outbound connections through Tor and inbound connections through a hidden
      service
    * [clightning](https://github.com/ElementsProject/lightning) with outbound connections through Tor, not listening
    * includes "nodeinfo" script which prints basic info about the node
    * adds non-root user "operator" which has access to bitcoin-cli and lightning-cli
* all
    * adds clightning hidden service
    * [liquid-daemon](https://github.com/blockstream/liquid)
    * [lightning charge](https://github.com/ElementsProject/lightning-charge)
    * [nanopos](https://github.com/ElementsProject/nanopos)
    * adds an index page using nginx to display node information and link to nanopos
    * [spark-wallet](https://github.com/shesek/spark-wallet)
        * Notes: run `nodeinfo` to get its onion address and `systemctl status spark-wallet` to get the access key.
            When entering the onion address on the Android app don't forgot to prepend "http://"

The data directories can be found in `/var/lib`.

Installing profiles
---
The easiest way is to use the provided network.nix and configuration.nix with [nixops](https://nixos.org/nixops/manual/).
Once you've set up nixops first run `./generate_secrets.sh` then continue with the deployment using nixops.

At the moment this relies on using the unstable nixpkgs channel.
The "all" profile requires 15 GB of disk space and 2GB of memory.

Tutorial: install a nix-bitcoin node on Debian 9 Stretch in a VirtualBox
---

Install Dependencies
```
sudo apt-get install curl git gnupg2 dirmngr
```
Install Latest Nix with GPG Verification
```
curl -o install-nix-2.1.3 https://nixos.org/nix/install
curl -o install-nix-2.1.3.sig https://nixos.org/nix/install.sig
gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
gpg2 --verify ./install-nix-2.1.3.sig
sh ./install-nix-2.1.3
. /home/user/.nix-profile/etc/profile.d/nix.sh
```
Add virtualbox.list to /etc/apt/sources.list.d
```
deb http://download.virtualbox.org/virtualbox/debian stretch contrib
```
Add Oracle VirtualBox public key
```
wget https://www.virtualbox.org/download/oracle_vbox_2016.asc
gpg2 oracle_vbox_2016.asc
```
Proceed _only_ if fingerprint reads B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF

```
sudo apt-key add oracle_vbox_2016.asc
```
Install virtualbox-5.2
```
sudo apt-get update
sudo apt-get install virtualbox-5.2
```
Currently there is an upstream bug in the nixops package which results in an error during `nixops create`. That is why we have to build nixops from source until a binary with the bug-fix is released.

Build Nixops from source
```
git clone https://github.com/NixOS/nixops
cd ~/nixops
nix-build release.nix -A build.x86_64-linux
cd
```
This should output a last line like `/nix/store/wa6nk3aqxjb2mgl9pkwrnawqnh9z1b9d-nixops-1.6.1pre0_abcdef/`. This is the directory Nixops is installed in. Note it for later.

Create Host Adapter in VirtualBox
```
Open VirtualBox
File -> Host Network Manager -> Create
This should create a hostadapter named vboxnet0
```
Clone this project
```
cd
git clone https://github.com/jonasnick/nix-bitcoin
cd ~/nix-bitcoin
```
Generate Secrets
```
./generate_secrets.sh
```
Create Nixops
```
nixops create network.nix network-vbox.nix -d bitcoin-node
```
Replace `nixops` with the path to the nixops you built from source. For example: `/nix/store/wa6nk3aqxjb2mgl9pkwrnawqnh9z1b9d-nixops-1.6.1pre0_abcdef/bin/nixops`. Alternatively you can change your path, i.e. `export PATH=/nix/store/wa6nk3aqxjb2mgl9pkwrnawqnh9z1b9d-nixops-1.6.1pre0_abcdef/bin/:$PATH` so you can just type nixops.

Deploy Nixops
```
nixops deploy -d bitcoin-node
```
If you haven't changed your nixops path, replace `nixops` with the path to the nixops you built from source. For example: `/nix/store/wa6nk3aqxjb2mgl9pkwrnawqnh9z1b9d-nixops-1.6.1pre0_abcdef/bin/nixops`

This will now create a nix-bitcoin node in a VirtualBox on your computer.

Nixops automatically creates a ssh key and adds it to your computer.

Access `bitcoin-node` through ssh

```
nixops ssh operator@bitcoin-node
```
If you haven't changed your nixops path, replace `nixops` with the path to the nixops you built from source. For example: `/nix/store/wa6nk3aqxjb2mgl9pkwrnawqnh9z1b9d-nixops-1.6.1pre0_abcdef/bin/nixops`
