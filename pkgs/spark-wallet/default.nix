{ pkgs, lib }:
let
  nodePackages = import ./composition.nix { inherit pkgs; };
in
nodePackages.package.override {
  # Required because spark-wallet uses `npm-shrinkwrap.json` as the lock file
  reconstructLock = true;

  meta = with lib; {
    description = "A minimalistic wallet GUI for c-lightning";
    homepage = "https://github.com/shesek/spark-wallet";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin erikarvstedt ];
    platforms = platforms.unix;
  };
}
