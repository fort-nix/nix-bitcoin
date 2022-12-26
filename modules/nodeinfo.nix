{ config, lib, pkgs, ... }:

with lib;
let
  options = {
    nix-bitcoin.nodeinfo = {
      enable = mkEnableOption "nodeinfo";

      program = mkOption {
        readOnly = true;
        default = script;
        defaultText = "(See source)";
      };

      services = mkOption {
        internal = true;
        type = types.attrs;
        default = {};
        defaultText = "(See source)";
        description = ''
          Nodeinfo service definitions.
        '';
      };

      lib = mkOption {
        internal = true;
        readOnly = true;
        default = nodeinfoLib;
        defaultText = "(See source)";
        description = ''
          Helper functions for defining nodeinfo services.
        '';
      };
    };
  };

  cfg = config.nix-bitcoin.nodeinfo;
  nbLib = config.nix-bitcoin.lib;

  script = pkgs.writeScriptBin "nodeinfo" ''
    #!${pkgs.python3}/bin/python

    import json
    import subprocess
    import sys
    from collections import OrderedDict

    def success(*args):
        return subprocess.call(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

    def is_active(unit):
        return success("systemctl", "is-active", "--quiet", unit)

    def is_enabled(unit):
        return success("systemctl", "is-enabled", "--quiet", unit)

    def cmd(*args):
        return subprocess.run(args, stdout=subprocess.PIPE).stdout.decode('utf-8')

    def shell(*args):
        return cmd("bash", "-c", *args).strip()

    infos = OrderedDict()
    operator = "${config.nix-bitcoin.operator.name}"

    def set_onion_address(info, name, port):
        path = f"/var/lib/onion-addresses/{operator}/{name}"
        try:
            with open(path, "r") as f:
                onion_address = f.read().strip()
        except OSError:
            print(f"error reading file {path}", file=sys.stderr)
            return
        info["onion_address"] = f"{onion_address}:{port}"

    def add_service(service, make_info):
        if not is_active(service):
            infos[service] = "service is not running"
        else:
            info = OrderedDict()
            exec(make_info, globals(), locals())
            infos[service] = info

    if is_enabled("onion-adresses") and not is_active("onion-adresses"):
        print("error: service 'onion-adresses' is not running")
        exit(1)

    ${concatStrings infos}

    print(json.dumps(infos, indent=2))
  '';

  infos = map (serviceName:
    let serviceCfg = config.services.${serviceName};
    in optionalString serviceCfg.enable (cfg.services.${serviceName} serviceName serviceCfg)
  ) (builtins.attrNames cfg.services);

  nodeinfoLib = rec {
    mkInfo = extraCode: name: cfg: ''
      add_service("${name}", """
      info["local_address"] = "${nbLib.addressWithPort cfg.address cfg.port}"
    '' + mkIfOnionPort name (onionPort: ''
      set_onion_address(info, "${name}", ${onionPort})
    '') + extraCode + ''

      """)
    '';

    mkIfOnionPort = name: fn:
      if onionServices ? ${name} then
        fn (toString (builtins.elemAt onionServices.${name}.map 0).port)
      else
        "";
  };

  inherit (config.services.tor.relay) onionServices;
in {
  inherit options;

  config = {
    environment.systemPackages = optional cfg.enable script;

    nix-bitcoin.nodeinfo.services = with nodeinfoLib; {
      bitcoind = mkInfo "";
      clightning = mkInfo ''
        info["nodeid"] = shell("lightning-cli getinfo | jq -r '.id'")
        if 'onion_address' in info:
            info["id"] = f"{info['nodeid']}@{info['onion_address']}"
      '';
      lnd = mkInfo ''
        info["nodeid"] = shell("lncli getinfo | jq -r '.identity_pubkey'")
      '';
      clightning-rest = mkInfo "";
      electrs = mkInfo "";
      fulcrum = mkInfo "";
      spark-wallet = mkInfo "";
      btcpayserver = mkInfo "";
      liquidd = mkInfo "";
      joinmarket-ob-watcher = mkInfo "";
      rtl = mkInfo "";
      lndhub-go = mkInfo "";
      # Only add sshd when it has an onion service
      sshd = name: cfg: mkIfOnionPort "sshd" (onionPort: ''
        add_service("sshd", """set_onion_address(info, "sshd", ${onionPort})""")
      '');
    };
  };
}
