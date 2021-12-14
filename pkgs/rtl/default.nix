{ pkgs, makeWrapper }:
let
  inherit (pkgs) nodejs;
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
})
