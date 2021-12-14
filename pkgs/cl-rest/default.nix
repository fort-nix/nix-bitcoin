{ pkgs, lib, makeWrapper }:
let
  inherit (pkgs) nodejs;
  nodePackages = import ./composition.nix { inherit pkgs nodejs; };
in
nodePackages.package.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
    makeWrapper
  ];

  postInstall = ''
    makeWrapper ${nodejs}/bin/node $out/bin/cl-rest \
      --add-flags $out/lib/node_modules/c-lightning-rest/cl-rest
  '';

  meta = with lib; {
    description = "REST API for C-Lightning";
    homepage = "https://github.com/Ride-The-Lightning/c-lightning-REST";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin earvstedt ];
    platforms = platforms.unix;
  };
})
