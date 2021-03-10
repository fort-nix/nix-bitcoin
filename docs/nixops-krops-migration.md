# Tutorial: Moving from a NixOps to a Krops deployment

1. Add a new ssh key to your nix-bitcoin node

   Krops doesn't automatically generate ssh keys like NixOps, instead you add your own.

   If you don't have a ssh key yet

   ```
   ssh-keygen -t ed25519 -f ~/.ssh/bitcoin-node
   ```

   Edit `configuration.nix`

   ```
   users.users.root = {
     openssh.authorizedKeys.keys = [
       "<contents of ~/.ssh/bitcoin-node.pub or existing .pub key file>"
     ];
   };
   ```

   Deploy new key

   ```
   nixops deploy -d bitcoin-node
   ```

2. Update your nix-bitcoin, depending on your setup either with `fetch-release` or `git`. Make sure you are at least on `v0.0.40`.

3. Pull the latest nix-bitcoin source

    ```
    cd ~/nix-bitcoin
    git pull
    ```

4. Copy new and updated files into your deployment folder

    ```
    cd <deployment directory, for example `~/nix-bitcoin-node`>
    cp -r ~/nix-bitcoin/examples/{krops,krops-configuration.nix,shell.nix} .
    ```

5. Edit your ssh config

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
        IdentityFile <ssh key from step 1 or path to existing key>
        AddKeysToAgent yes
    ```

6. Make sure you are in the deployment directory and edit `krops/deploy.nix`

    ```
    nano krops/deploy.nix
    ```

    Locate the `FIXME` and set the target to the name of the ssh config entry created earlier, i.e. `bitcoin-node`.

7. If `lnd` or `joinmarket` is enabled on your node, run the commmand
   ```
   nix-shell --run 'nix-instantiate --eval -E "
     (import <nixpkgs/nixos> {
       configuration = { lib, ... }: {
         imports = [ ./krops-configuration.nix ];
         nix-bitcoin.configVersion = lib.mkDefault \"0.0.31\";
       };
     }).vm.outPath
   "'
   ```
   and follow the migration instructions from the error message.

8. Deploy with krops

    ```
    nix-shell --run krops-deploy
    ```
    Remove the old secrets directory. For krops deployments, secrets are always
    located at `/var/src/secrets`.
    ```
    ssh bitcoin-node 'rm -rf /secrets'
    ```

9. You can now access `bitcoin-node` via ssh

    ```
    ssh operator@bitcoin-node
    ```
