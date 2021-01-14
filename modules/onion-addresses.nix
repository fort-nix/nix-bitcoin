# This module enables unprivileged users to read onion addresses.
# By default, onion addresses in /var/lib/tor/onion are only readable by the
# tor user.
# The included service copies onion addresses to /var/lib/onion-addresses/<user>/
# and sets permissions according to option 'access'.

{ config, lib, ... }:

with lib;

let
  cfg = config.nix-bitcoin.onionAddresses;
  inherit (config) nix-bitcoin-services;
  dataDir = "/var/lib/onion-addresses/";
in {
  options.nix-bitcoin.onionAddresses = {
    access = mkOption {
      type = with types; attrsOf (listOf str);
      default = {};
      description = ''
        This option controls who is allowed to access onion addresses.
        For example, the following allows user 'myuser' to access bitcoind
        and clightning onion addresses:
        {
          "myuser" = [ "bitcoind" "clightning" ];
        };
        The onion hostnames can then be read from
        /var/lib/onion-addresses/myuser.
      '';
    };
  };

  config = mkIf (cfg.access != {}) {
    systemd.services.onion-addresses = {
      wantedBy = [ "tor.service" ];
      bindsTo = [ "tor.service" ];
      after = [ "tor.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "onion-addresses";
        PrivateNetwork = "true"; # This service needs no network access
        PrivateUsers = "false";
        CapabilityBoundingSet = "CAP_CHOWN CAP_FSETID CAP_SETFCAP CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_IPC_OWNER";
      };
      script = ''
        # Wait until tor is up
        until [[ -e /var/lib/tor/state ]]; do sleep 0.1; done

        cd ${dataDir}
        rm -rf *

        ${concatMapStrings
          (user: ''
            mkdir -p -m 0700 ${user}
            chown ${user} ${user}
            ${concatMapStrings
              (service: ''
                onionFile=/var/lib/tor/onion/${service}/hostname
                if [[ -e $onionFile ]]; then
                  cp $onionFile ${user}/${service}
                  chown ${user} ${user}/${service}
                fi
              '')
              cfg.access.${user}
            }
          '')
          (builtins.attrNames cfg.access)
        }
      '';
    };
  };
}
