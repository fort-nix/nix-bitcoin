{ pkgs, lib, makeWrapper }:
let
  inherit (pkgs) nodejs;
  # TODO-EXTERNAL: if we don't set nodejs to version 14 then we get the
  # following dependency error from npm:
  #   > npm WARN peer jasmine-core@">=3.8" from karma-jasmine-html-reporter@1.7.0
  #   > npm WARN node_modules/karma-jasmine-html-reporter
  #   > npm WARN   dev karma-jasmine-html-reporter@"^1.5.0" from the root project
  #   > npm ERR! code ENOTCACHED
  # This error presumably goes away with RTL 0.13.
  nodePackages = import ./composition.nix { inherit pkgs; nodejs = pkgs."nodejs-14_x"; };
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
