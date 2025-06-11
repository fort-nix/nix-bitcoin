# shellcheck disable=SC2154
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Docs
# https://github.com/Ride-The-Lightning/RTL
# config options: https://github.com/Ride-The-Lightning/RTL/blob/master/.github/docs/Application_configurations.md
# https://github.com/Ride-The-Lightning/c-lightning-REST
# local src: ~/s/RTL/

# Browse API docs (in container shell)
runuser -u "$(logname)" -- xdg-open "http://$ip:4001/api-docs/"

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Debug the service
run-tests.sh -s rtl-dev container

c systemctl status rtl
c journalctl -u rtl
c cat /var/lib/rtl/RTL-Config.json

# Open webinterface. Password: a
runuser -u "$(logname)" -- xdg-open "http://$ip:3000"

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Build RTL manually
# [[~/s/RTL/dockerfiles/Dockerfile][dockerfile]]
# [[~/s/RTL/package.json][package.json]]

rtl_src=~/s/RTL
git clone https://github.com/Ride-The-Lightning/RTL "$rtl_src"

nix build -o /tmp/nix-bitcoin-dev/nodejs --inputs-from . nixpkgs#nodejs_22
# Start a shell in a sandbox
env --chdir "$rtl_src" nix-bitcoin-firejail --whitelist="$rtl_src" --whitelist=/tmp/nix-bitcoin-dev/nodejs
PATH=/tmp/nix-bitcoin-dev/nodejs/bin:"$PATH"

# Install
npm ci --omit=dev --omit=optional --no-update-notifier --ignore-scripts
# If the above fails, try: (details: https://github.com/Ride-The-Lightning/RTL/issues/1182)
npm ci --omit=dev --omit=optional --no-update-notifier --ignore-scripts --legacy-peer-deps


# Run
node rtl --help

git clean -xdf # Cleanup repo
