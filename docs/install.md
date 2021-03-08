Preliminary steps
---
Get a machine to deploy nix-bitcoin on.

# Tutorials

1. [Install and configure NixOS for nix-bitcoin on your own hardware](#tutorial-install-and-configure-nixos-for-nix-bitcoin-on-your-own-hardware)

----

Tutorial: install and configure NixOS for nix-bitcoin on your own hardware
---

## 0. Preparation

1. Optional: Make sure you have the latest firmware for your system (BIOS, microcode updates).

2. Optional: Disable Simultaneous Multi-Threading (SMT) in the BIOS

    Researchers recommend disabling (SMT), also known as Hyper-Threading Technology in the Intel® world to significantly reduce the impact of speculative execution-based attacks (https://mdsattacks.com/).

## 1. NixOS installation

This is borrowed from the [NixOS manual](https://nixos.org/nixos/manual/index.html#ch-installation). Look there for more information.

1. Obtain latest [NixOS](https://nixos.org/nixos/download.html). For example:

    ```
    wget https://releases.nixos.org/nixos/19.09/nixos-19.09.2284.bf7c0f0461e/nixos-minimal-19.09.2284.bf7c0f0461e-x86_64-linux.iso
    sha256sum nixos-minimal-19.09.2284.bf7c0f0461e-x86_64-linux.iso
    # output: 9768eb945bef410fccfb82cb3d2e7ce7c02c3430aed0f2f1527273cb080fff3e
    ```
    Alternatively you can build NixOS from source by following the instructions at https://nixos.org/nixos/manual/index.html#sec-building-cd.

2. Write NixOS iso to install media (USB/CD). For example:

    ```
    cp nixos-minimal-19.09.2284.bf7c0f0461e-x86_64-linux.iso /dev/sdX
    ```

    Replace /dev/sdX with the correct device name. You can find this using `sudo fdisk -l`

3. Boot the system

    You will have to find out if your hardware uses UEFI or Legacy Boot for the next step.

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

    Option 1: Edit NixOS configuration for UEFI

    ```
    { config, pkgs, ... }: {
      imports = [
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
      ];

      boot.loader.systemd-boot.enable = true;

      # Note: setting fileSystems is generally not
      # necessary, since nixos-generate-config figures them out
      # automatically in hardware-configuration.nix.
      #fileSystems."/".device = "/dev/disk/by-label/nixos";

      # Enable the OpenSSH server.
      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };
    }
    ```

    Option 2: Edit NixOS configuration for Legacy Boot (MBR)

    ```
    { config, pkgs, ... }: {
      imports = [
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
      ];

      boot.loader.grub.device = "/dev/sda";

      # Note: setting fileSystems is generally not
      # necessary, since nixos-generate-config figures them out
      # automatically in hardware-configuration.nix.
      #fileSystems."/".device = "/dev/disk/by-label/nixos";

      # Enable the OpenSSH server.
      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };
    }
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

1. Install Dependencies (Debian 9 stretch)

    ```
    sudo apt-get install curl git gnupg2 dirmngr
    ```

2. Install latest Nix in "multi-user mode" with GPG Verification according to https://nixos.org/nix/download.html

    ```
    curl -o install-nix-2.3.3 https://releases.nixos.org/nix/nix-2.3.3/install
    curl -o install-nix-2.3.3.asc https://releases.nixos.org/nix/nix-2.3.3/install.asc
    gpg2 --recv-keys B541D55301270E0BCF15CA5D8170B4726D7198DE
    gpg2 --verify ./install-nix-2.3.3.asc
    sh ./install-nix-2.3.3 --daemon
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
    # TODO
    cp -r ../nix-bitcoin/examples/{configuration.nix,shell.nix,nix-bitcoin-release.nix} .
    ```

## 4. Deploy with TODO
1. TODO
2. Edit `configuration.nix`

    ```
    nano configuration.nix
    ```

    Uncomment `./hardware-configuration.nix` line by removing #.

3. Create `hardware-configuration.nix`.

    ```
    nano hardware-configuration.nix
    ```

    Copy contents of your NixOS machine's `/etc/nixos/hardware-configuration.nix` to this file.

4. Add boot option to `hardware-configuration.nix`

    Option 1: Enable systemd boot for UEFI

    ```
    boot.loader.systemd-boot.enable = true;
    ```

    Option 2: Set grub device for Legacy Boot (MBR)

    ```
    boot.loader.grub.device = "/dev/sda";
    ```

5. Enter environment

    ```
    nix-shell
    ```

    NOTE that a new directory `secrets/` appeared which contains the secrets for your node.

6. TODO
7. Adjust configuration by opening the `configuration.nix` file and enable/disable the modules you want by editing this file. Pay particular attention to lines that are preceded by `FIXME` comments.

8. TODO

For security reasons, all normal system management tasks can and should be performed with the `operator` user. Logging in as `root` should be done as rarely as possible.

See [usage.md](usage.md) for usage instructions, such as how to update.
