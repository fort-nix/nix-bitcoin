## Issues with the backend that complicate packaging

- Backend expects file `mempool-config.json` to reside in source code at
  `../mempool-config.json`, relative to file `$pkg/lib/node_modules/mempool-backend/dist/index.js`

- Backend expects file `../.git/refs/heads/master` to exist relative to the working
  dir. This is used for constructing a version string.

- Backend must be run with working dir `$pkg/lib/node_modules/mempool-backend` so
  that file `package.json` can be read relative to PWD.

`mempool-backend.workaround` works around these issues. Demo:
```shell
nix build ../..#mempool-backend.workaround --out-link /tmp/mempool
# Run the backend in a sandbox
nix shell nixpkgs#bubblewrap -c bwrap --unshare-net --ro-bind / / -- /tmp/mempool/bin/mempool-backend
```
