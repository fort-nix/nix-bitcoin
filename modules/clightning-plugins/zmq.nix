{ config, lib, ... }:

with lib;
let
  options.services.clightning.plugins.zmq = {
    enable = mkEnableOption "ZMQ (clightning plugin)";
  } // lib.genAttrs endpoints mkEndpointOption;

  cfg = config.services.clightning.plugins.zmq;

  nbLib = config.nix-bitcoin.lib;

  endpoints = [
    "channel-opened"
    "connect"
    "disconnect"
    "invoice-payment"
    "warning"
    "forward-event"
    "sendpay-success"
    "sendpay-failure"
  ];

  mkEndpointOption = name:
    mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Endpoint for ${name}";
    };

  setEndpoint = ep:
    let value = builtins.getAttr ep cfg; in
    optionalString (value != null) ''
      zmq-pub-${ep}=${value}
    '';
in
{
  inherit options;

  config = mkIf cfg.enable {
    services.clightning.extraConfig = ''
      plugin=${config.nix-bitcoin.pkgs.clightning-plugins.zmq.path}
      ${concatStrings (map setEndpoint endpoints)}
    '';

    # The zmq server requires AF_NETLINK
    systemd.services.clightning.serviceConfig.RestrictAddressFamilies =
      mkForce nbLib.allowNetlink.RestrictAddressFamilies;
  };
}
