#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

destDir=${1:-nix-bitcoin}

scriptDir=$(cd "${BASH_SOURCE[0]%/*}" && pwd)

mkdir -p "$destDir/"{bin,lib}
cd "$destDir"

if [[ ! -e src ]]; then
    echo "Cloning fort-nix/nix-bitcoin"
    git clone https://github.com/fort-nix/nix-bitcoin src
fi

echo 'export root=$PWD
export src=$root/src
PATH_add bin
PATH_add src/helper' > .envrc

if [[ ! -e scenarios.nix ]]; then
    cp "$scriptDir/template-scenarios.nix" scenarios.nix
fi

install -m 755 <(
    echo '#!/usr/bin/env bash'
    echo 'exec run-tests.sh --extra-scenarios "$root/scenarios.nix" "$@"'
) bin/dev-run-tests

install -m 755 <(
    echo '#!/usr/bin/env bash'
    echo 'exec $root/src/test/run-tests.sh --out-link-prefix /tmp/nix-bitcoin/test "$@"'
) bin/run-tests.sh

ln -sfn dev-run-tests bin/te

## nix-bitcoin-firejail

echo '# Add your shell config files here that should be accessible in the sandbox
whitelist ${HOME}/.bashrc
read-only ${HOME}/.bashrc' > lib/nix-bitcoin-firejail.conf

install -m 755 <(
    echo '#!/usr/bin/env bash'
    echo '# A sandbox for running shells/binaries in an isolated environment:'
    echo '# - The sandbox user is the calling user, with all capabilities dropped'
    echo '#   and with no way to gain new privileges (e.g. via `sudo`).'
    echo '# - $HOME is bind-mounted to a dir that only contains shell config files and files required by direnv.'
    echo '#'
    echo '# You can modify the firejail env by editing `lib/nix-bitcoin-firejail.conf` in your dev env dir.'
    echo 'exec firejail --profile="$root/lib/nix-bitcoin-firejail.conf" --profile="$root/src/dev/dev-env/nix-bitcoin-firejail.conf" "$@"'
) bin/nix-bitcoin-firejail

echo "1" > lib/dev-env-version

## git

echo '/src' > .gitignore

if [[ ! -e .git ]]; then
    git init
    git add .
    git commit -a -m init
fi
