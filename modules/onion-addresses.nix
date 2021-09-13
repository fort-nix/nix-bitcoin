# This module enables unprivileged users to read onion addresses.
# By default, onion addresses in /var/lib/tor/onion are only readable by the
# tor user.
# The included service copies onion addresses to /var/lib/onion-addresses/<user>/
# and sets permissions according to option 'access'.

{ config, lib, ... }:

with lib;
let
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
    services = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        Services that can access their onion address via file
        /var/lib/onion-addresses/<service>
        The file is readable only by the service user.
      '';
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/onion-addresses";
    };
  };

  cfg = config.nix-bitcoin.onionAddresses;
  nbLib = config.nix-bitcoin.lib;
in {
  inherit options;

  config = mkIf (cfg.access != {} || cfg.services != []) {
    systemd.services.onion-addresses = {
      wantedBy = [ "tor.service" ];
      bindsTo = [ "tor.service" ];
      after = [ "tor.service" ];
      serviceConfig = nbLib.defaultHardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "onion-addresses";
        StateDirectoryMode = "771";
        PrivateNetwork = "true"; # This service needs no network access
        PrivateUsers = "false";
        CapabilityBoundingSet = "CAP_CHOWN CAP_FSETID CAP_SETFCAP CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_IPC_OWNER";
      };
      script = ''
        # Wait until tor is up
        until [[ -e /var/lib/tor/state ]]; do sleep 0.1; done

        cd ${cfg.dataDir}
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

        ${concatMapStrings (service: ''
          onionFile=/var/lib/tor/onion/${service}/hostname
          if [[ -e $onionFile ]]; then
            install -D -o ${config.systemd.services.${service}.serviceConfig.User} -m 400 $onionFile services/${service}
          fi
        '') cfg.services}
      '';
    };
  };
}
