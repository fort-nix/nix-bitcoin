#!/usr/bin/env bash

# Usage:
#
#   run-tests.sh [--scenario|-s <scenario>] container
#
#     Start container and start a shell session with helper commands
#     for accessing the container.
#     A short command documentation is printed at the start of the session.
#     The container is destroyed after exiting the shell.
#     An existing container is destroyed before starting.
#
#     Supported arguments:
#
#       --destroy|-d to destroy
#
#         When `run-tests.sh container` from inside an existing shell session,
#         the current container is updated without restarting by switching
#         its NixOS configuration.
#         Use this arg to destroy and restart the container instead.
#
#       --no-destroy|-n
#
#         By default, all commands destroy an existing container before starting and,
#         when appropriate, before exiting.
#         This ensures that containers start with no leftover filesystem state from
#         previous runs and that containers don't consume system resources after use.
#         This args disables auto-destructing containers.
#
#
#   run-tests.sh container --run c systemctl status bitcoind
#
#     Run a command in the shell session environmentand exit.
#     Destroy the container afterwards.
#     All arguments following `--run` are used as a command.
#     Supports argument '--no-destroy|-n' (see above for an explanation).
#
#     Example: Start shell inside container
#     run-tests.sh container --run c
#
#
#   run-tests.sh [--scenario|-s <scenario>] container --command|-c
#
#     Provide a custom extra-container command.
#
#     Example:
#       run-tests.sh container --command create -s
#       Create and start a container without a shell.
#
#
#   All extra args are passed to extra-container (unless --command is used):
#   run-tests.sh container --build-args --builders 'ssh://worker - - 8'

set -euo pipefail

# These vars are set by ../run-tests.sh
: "${container:=}"
: "${scriptDir:=}"

containerCommand=shell

while [[ $# -gt 0 ]]; do
    case $1 in
        --command|-c)
            shift
            containerCommand=$1
            shift
            ;;
        *)
            break
    esac
done

containerBin=$(type -P extra-container) || true
if [[ ! ($containerBin && $(realpath "$containerBin") == *extra-container-0.12*) ]]; then
    echo
    echo "Building extra-container. Skip this step by adding extra-container 0.12 to PATH."
    nix build --out-link /tmp/extra-container "$scriptDir"/..#extra-container
    # When this script is run as root, e.g. when run in an extra-container shell,
    # chown the gcroot symlink to the regular (login) user so that the symlink can be
    # overwritten when this script is run without root.
    if [[ $EUID == 0 ]]; then
        chown "$(logname):" --no-dereference /tmp/extra-container
    fi
    export PATH="/tmp/extra-container/bin${PATH:+:}$PATH"
fi

exec "$container"/bin/container "$containerCommand" "$@"
