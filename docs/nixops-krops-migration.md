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

2. Update your nix-bitcoin, depending on your setup either with `fetch-release` or `git`. Make sure you are at least on `v0.0.41`.

3. Pull the latest nix-bitcoin source

    ```
    cd ~/nix-bitcoin
    git pull
    ```

4. Copy new and updated files into your deployment folder

    ```
    cd <deployment directory, for example `~/nix-bitcoin-node`>
    cp -r ~/nix-bitcoin/examples/{krops,shell.nix} .
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

    Note that any file imported by your `configuration.nix` must be copied to the target machine by krops.
    For example, if there is an import of `networking.nix` you must add it to `extraSources` in `krops/deploy.nix` like this:
    ```
    extraSources = {
        "hardware-configuration.nix".file = toString ../hardware-configuration.nix;
        "networking.nix".file = toString ../networking.nix;
    };
    ```

7. If `lnd` or `joinmarket` is enabled on your node, run the commmand
   ```
   nix-shell --run 'nix-instantiate --eval -E "
     (import <nixpkgs/nixos> {
       configuration = { lib, ... }: {
         imports = [ ./configuration.nix ];
         nix-bitcoin.configVersion = lib.mkDefault \"0.0.31\";
         nix-bitcoin.secretsSetupMethod = lib.mkForce \"manual\";
       };
     }).vm.outPath
   "'
   ```
   and follow the migration instructions from the error message.

8. Optional: Disallow substitutes

    You may have been building nix-bitcoin "without substitutes" to avoid pulling in binaries from the Nix cache. If you want to continue doing so, you have to add the following line to the `configuration.nix`:
    ```
    nix.extraOptions = "substitute = false";
    ```

    If the build process fails for some reason when deploying with `krops-deploy` (see later step), it may be difficult to find the cause due to the missing output.
    In that case, it is possible to SSH into the target machine and run
    ```
    nixos-rebuild -I /var/src switch
    ```

9. Deploy with krops

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

10. You can remove the remaining traces of nixops as follows:
    ```
    nix-shell
    nix run -f '<nix-bitcoin>' nixops19_09 -c nixops delete -d bitcoin-node --force
    git rm -r nixops
    ```
