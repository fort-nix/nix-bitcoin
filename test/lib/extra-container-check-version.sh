containerBin=$(type -P extra-container) || true
if [[ ! ($containerBin && $(realpath "$containerBin") == *extra-container-0.12*) ]]; then
    echo
    echo "Building extra-container. Skip this step by adding extra-container 0.12 to PATH."
    nix build --out-link /tmp/extra-container "${BASH_SOURCE[0]%/*}"/../..#extra-container
    # When this script is run as root, e.g. when run in an extra-container shell,
    # chown the gcroot symlink to the regular (login) user so that the symlink can be
    # overwritten when this script is run without root.
    if [[ $EUID == 0 ]]; then
        chown "$(logname):" --no-dereference /tmp/extra-container
    fi
    export PATH="/tmp/extra-container/bin${PATH:+:}$PATH"
fi
