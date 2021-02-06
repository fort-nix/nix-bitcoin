# Re-run run-tests.sh in a snapshot copy of the source.
# Maintain /tmp/nix-bitcoin-src as a source cache to minimize copies.

tmp=$(mktemp -d '/tmp/nix-bitcoin-src.XXXXX')

# Ignore errors from now on
set +e

# Move source cache if it exists (atomic)
mv /tmp/nix-bitcoin-src $tmp/src 2>/dev/null

rsync -a --delete --exclude='.git*' "$scriptDir/../" $tmp/src && \
  echo "Copied src" && \
  _nixBitcoinInCopySrc=1 $tmp/src/test/run-tests.sh "${args[@]}"

# Set the current src as the source cache (atomic)
mv -T $tmp/src /tmp/nix-bitcoin-src 2>/dev/null
rm -rf $tmp
