# Re-run run-tests.sh in a snapshot copy of the source.
# Maintain /tmp/nix-bitcoin-src as a source cache to minimize copies.

tmp=$(mktemp -d '/tmp/nix-bitcoin-src.XXXXX')

# Move source cache if it exists (atomic)
mv /tmp/nix-bitcoin-src "$tmp/src" 2>/dev/null || true

atExit() {
    # Set the current src as the source cache (atomic)
    mv -T "$tmp/src" /tmp/nix-bitcoin-src 2>/dev/null || true
    rm -rf "$tmp"
}
trap "atExit" EXIT

# shellcheck disable=SC2154
rsync -a --delete --exclude='.git*' "$scriptDir/../" "$tmp/src"
echo "Copied src"

# shellcheck disable=SC2154
_nixBitcoinInCopiedSrc=1 "$tmp/src/test/run-tests.sh" "${args[@]}"
