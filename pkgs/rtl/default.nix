{ pkgs, lib, makeWrapper }:
let
  nodejs = pkgs.nodejs-14_x;
  nodePackages = import ./composition.nix { inherit pkgs nodejs; };
in
nodePackages.package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
    makeWrapper
  ];

  postInstall = ''
    makeWrapper ${nodejs}/bin/node $out/bin/rtl \
      --add-flags $out/lib/node_modules/rtl/rtl
  '';

  meta = with lib; {
    description = "A web interface for LND, c-lightning and Eclair";
    homepage = "https://github.com/Ride-The-Lightning/RTL";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
})
