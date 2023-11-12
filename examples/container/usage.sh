# Requirements:
# - A systemd-based Linux distro
# - extra-container (https://github.com/erikarvstedt/extra-container/#install)
# - Nix
# - Root privileges

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Create container

# Create and start container defined by ./flake.nix
nix run . -- create --start
# You can use the same command to update the (running) container,
# after changing the container configuration.

# In the default configuration, the container is automatically started on
# system boot (option `autoStart`).

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Use container

# Run command in container
extra-container run mynode -- hostname
extra-container run mynode -- systemctl status bitcoind
extra-container run mynode -- lightning-cli getinfo
extra-container run mynode -- bash -c 'bitcoin-cli -getinfo && lightning-cli getinfo'

# Start shell in container
extra-container root-login mynode

# Show the container filesystem
sudo ls -al /var/lib/nixos-containers/mynode

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Stop container
extra-container stop mynode

# Resume the container
extra-container start mynode
# You can also use the `create --start` command above

# Destroy container
nix run . -- destroy

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Inspect container config
nix eval .#default.outPath
nix eval . --apply 'sys: sys.containers.mynode.config.networking.hostName'
