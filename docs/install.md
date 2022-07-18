# Tutorial: Install and configure NixOS for nix-bitcoin on a dedicated machine

This tutorial describes how to manage your Bitcoin node comfortably from your personal computer with the deployment tool [krops](https://github.com/krebs/krops).
However, nix-bitcoin is agnostic to the deployment method and can be used with different or without such tools (see [examples](../examples/README.md)).

## 0. Preparation

1. Find a machine to deploy nix-bitcoin on (see [hardware.md](hardware.md)).

2. Optional: Make sure you have the latest firmware for your system (BIOS, microcode updates).

3. Optional: Disable Simultaneous Multi-Threading (SMT) in the BIOS

    Researchers recommend disabling (SMT), also known as Hyper-Threading Technology in the Intel® world to significantly reduce the impact of speculative execution-based attacks (https://mdsattacks.com/).

## 1. NixOS installation

This is borrowed from the [NixOS manual](https://nixos.org/nixos/manual/index.html#ch-installation). Look there for more information.

1. Obtain latest [NixOS](https://nixos.org/nixos/download.html). For example:

    ```
    wget https://releases.nixos.org/nixos/20.09/nixos-20.09.2405.e065200fc90/nixos-minimal-20.09.2405.e065200fc90-i686-linux.iso
    sha256sum nixos-minimal-20.09.2405.e065200fc90-x86_64-linux.iso
    # output: 5fc182e27a71a297b041b5c287558b21bdabde7068d4fc049752dad3025df867
    ```
    Alternatively you can build NixOS from source by following the instructions at https://nixos.org/nixos/manual/index.html#sec-building-cd.

2. Write NixOS iso to install media (USB/CD). For example:

    ```
    cp nixos-minimal-20.09.2405.e065200fc90-x86_64-linux.iso /dev/sdX
    ```

    Replace /dev/sdX with the correct device name. You can find this using `sudo fdisk -l`

3. Boot the system and become root

    ```
    sudo -i
    ```

    You will have to find out if your hardware uses UEFI or Legacy Boot for the next step. You can do that, for example, by executing

    ```
    ls /sys/firmware/efi
    ```

    If the file exists exists, you should continue the installation for UEFI otherwise for Legacy Boot.


4. Option 1: Partition and format for UEFI

    ```
    parted /dev/sda -- mklabel gpt
    parted /dev/sda -- mkpart primary 512MiB -8GiB
    parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
    parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/sda -- set 3 boot on
    mkfs.ext4 -L nixos /dev/sda1
    mkswap -L swap /dev/sda2
    mkfs.fat -F 32 -n boot /dev/sda3
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
    swapon /dev/sda2
    ```

4. Option 2: Partition and format for Legacy Boot (MBR)

    ```
    parted /dev/sda -- mklabel msdos
    parted /dev/sda -- mkpart primary 1MiB -8GiB
    parted /dev/sda -- mkpart primary linux-swap -8GiB 100%
    mkfs.ext4 -L nixos /dev/sda1
    mkswap -L swap /dev/sda2
    mount /dev/disk/by-label/nixos /mnt
    swapon /dev/sda2
    ```

4. Option 3: Set up encrypted partitions:

    Follow the guide at https://gist.github.com/martijnvermaat/76f2e24d0239470dd71050358b4d5134.

5. Generate NixOS config

    ```
    nixos-generate-config --root /mnt
    nano /mnt/etc/nixos/configuration.nix
    ```

    We now need to adjust the configuration to make sure that we can ssh into the system and that it boots correctly. We add some lines to set `services.openssh` such that the configuration looks as follows:

    ```
    { config, pkgs, ... }:

    {
      imports = [
        ...
      ];

      # Enable the OpenSSH server.
      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };

      # The rest of the file are default options and hints.
    }
    ```

    Now we open `hardware-configuration.nix`

    ```
    nano /mnt/etc/nixos/hardware-configuration.nix
    ```

    which will look similar to

    ```
    { config, pkgs, ... }:

    {
      imports = [ ];

      # Add line here as explained below

      # The rest of the file are generated options.
    }
    ```

    Now add one of the following lines to the location mentioned in above example hardware config.

    **Option 1**: UEFI

    ```
      boot.loader.systemd-boot.enable = true;
    ```

    **Option 2**: Legacy Boot (MBR)

    ```
      boot.loader.grub.device = "/dev/sda";
    ```

    Lastly, in rare circumstances the hardware configuration does not have a `fileSystems` option. In that case you need to add it with the folllowing line:

    ```
      fileSystems."/".device = "/dev/disk/by-label/nixos";
    ```

6. Do the installation

    ```
    nixos-install
    ```

    Set root password

    ```
    setting root password...
    Enter new UNIX password:
    Retype new UNIX password:
    ```

7. If everything went well

    ```
    reboot
    ```

## 2. Nix installation
The following steps are meant to be run on the machine you deploy from, not the machine you deploy to.
You can also build Nix from source by following the instructions at https://nixos.org/nix/manual/#ch-installing-source.

1. Install Dependencies (Debian 10 Buster)

    ```
    sudo apt-get install curl git gnupg2 dirmngr
    ```

2. Install latest Nix in "multi-user mode" with GPG Verification according to https://nixos.org/nix/download.html

    ```
    curl -o install-nix-2.3.10 https://releases.nixos.org/nix/nix-2.3.10/install
    curl -o install-nix-2.3.10.asc https://releases.nixos.org/nix/nix-2.3.10/install.asc
    gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
    gpg2 --verify ./install-nix-2.3.10.asc
    sh ./install-nix-2.3.10 --daemon
    ```

    Then follow the instructions. Open a new terminal window when you're done.

    If you get an error similar to

    ```
    error: cloning builder process: Operation not permitted
    error: unable to start build process
    /tmp/nix-binary-tarball-unpack.hqawN4uSPr/unpack/nix-2.2.1-x86_64-linux/install: unable to install Nix into your default profile
    ```

    you're likely not installing as multi-user because you forgot to pass the `--daemon` flag to the install script.

3. Optional: Disallow substitutes

    You can put `substitute = false` to your `nix.conf` usually found in `/etc/nix/` to build the packages from source.
    This eliminates an attack vector where nix's build server or binary cache is compromised.

## 3. Setup deployment directory

1. Clone this project

    ```
    cd
    git clone https://github.com/fort-nix/nix-bitcoin
    ```

2. Obtain the hash of the latest nix-bitcoin release

    ```
    cd nix-bitcoin/examples
    nix-shell
    ```

    This will download the nix-bitcoin dependencies and might take a while without giving an output.
    Now in the nix-shell run

    ```
    fetch-release > nix-bitcoin-release.nix
    ```

3. Create a new directory for your nix-bitcoin deployment and copy initial files from nix-bitcoin

    ```
    cd ../../
    mkdir nix-bitcoin-node
    cd nix-bitcoin-node
    cp -r ../nix-bitcoin/examples/{nix-bitcoin-release.nix,configuration.nix,shell.nix,krops,.gitignore} .
    ```

#### Optional: Specify the system of your node
   This enables evaluating your node config on a machine that has a different system platform
   than your node.\
   Examples: Deploying from macOS or deploying from a x86 desktop PC to a Raspberry Pi.

    ```
    # Run this when your node has a 64-Bit x86 CPU (e.g., an Intel or AMD CPU)
    echo "x86_64-linux" > krops/system

    # Run this when your node has a 64-Bit ARM CPU (e.g., Raspberry Pi 4 B, Pine64)
    echo "aarch64-linux" > krops/system
    ```
    Other available systems:
    - `i686-linux` (`x86`)
    - `armv7l-linux` (`ARMv7`)\
      This platform is untested and has no binary caches.
      [See here](https://nixos.wiki/wiki/NixOS_on_ARM) for details.

## 4. Deploy with krops

1. Edit your ssh config

    ```
    nano ~/.ssh/config
    ```

    and add the node with an entry similar to the following (make sure to fix `Hostname` and `IdentityFile`):

    ```
    Host bitcoin-node
        # FIXME
        Hostname NODE_IP_ADDRESS_OR_HOST_NAME_HERE
        User root
        PubkeyAuthentication yes
        # FIXME
        IdentityFile ~/.ssh/id_...
        AddKeysToAgent yes
    ```

2. Make sure you are in the deployment directory and edit `krops/deploy.nix`

    ```
    nano krops/deploy.nix
    ```

    Locate the `FIXME` and set the target to the name of the ssh config entry created earlier, i.e. `bitcoin-node`.

    Note that any file imported by your `configuration.nix` must be copied to the target machine by krops.
    For example, if there is an import of `networking.nix` you must add it to `extraSources` in `krops/deploy.nix` like this:
    ```
    extraSources = {
        "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
        "networking.nix".file = toString ../networking.nix;
    };
    ```

3. Optional: Disallow substitutes

    If you prefer to build the system from source instead of copying binaries from the Nix cache, add the following line to `configuration.nix`:
    ```
    nix.extraOptions = "substitute = false";
    ```

    If the build process fails for some reason when deploying with `krops-deploy` (see later step), it may be difficult to find the cause due to the missing output.
    To see the build output, SSH into the target machine and run
    ```
    nixos-rebuild -I /var/src switch
    ```

4. Copy `hardware-configuration.nix` from your node to the deployment directory.

    ```
    scp root@bitcoin-node:/etc/nixos/hardware-configuration.nix .
    ```

5. Adjust configuration by opening the `configuration.nix` file and enable/disable the modules you want by editing this file.

    ```
    nano configuration.nix
    ```

    Pay attention to lines that are preceded by `FIXME` comments. In particular:
    1. Make sure to set your SSH pubkey. Otherwise, you loose remote access because the config does not enable `permitRootLogin` (unless you add that manually).
    2. Uncomment the line `./hardware-configuration.nix` by removing `#`.

6. Enter the deployment environment

    ```
    nix-shell
    ```

7. Deploy with krops in nix-shell

    ```
    deploy
    ```

    This will now create a nix-bitcoin node on the target machine.

8. You can now access `bitcoin-node` via ssh

    ```
    ssh operator@bitcoin-node
    ```

    Note that you're able to log in as the unprivileged `operator` user because nix-bitcoin automatically authorizes the ssh key added to `root`.

For security reasons, all normal system management tasks can and should be performed with the `operator` user. Logging in as `root` should be done as rarely as possible.

See also:
- [Migrating existing services to bitcoind](configuration.md#migrate-existing-services-to-nix-bitcoin)
- [Managing your deployment](configuration.md#managing-your-deployment)
- [Using services](services.md)
