# This module enables unprivileged users to read onion addresses.
# By default, onion addresses in /var/lib/tor/onion are only readable by the
# tor user.
# The included service copies onion addresses to /var/lib/onion-addresses/<user>/
# and sets permissions according to option 'access'.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin.onionAddresses;
  inherit (config) nix-bitcoin-services;
  dataDir = "/var/lib/onion-addresses/";
  onion-addresses-script = pkgs.writeScript "onion-addresses.sh" ''
    # wait until tor is up
    until ls -l /var/lib/tor/state; do sleep 1; done

    cd ${dataDir}

    # Create directory for every user and set permissions
    ${ builtins.foldl'
      (x: user: x +
        ''
        mkdir -p -m 0700 ${user}
        chown ${user} ${user}
          # Copy onion hostnames into the user's directory
          ${ builtins.foldl'
            (x: onion: x +
              ''
              ONION_FILE=/var/lib/tor/onion/${onion}/hostname
              if [ -e "$ONION_FILE" ]; then
                cp $ONION_FILE ${user}/${onion}
                chown ${user} ${user}/${onion}
              fi
              '')
            ""
            (builtins.getAttr user cfg.access)
          }
        '')
      ""
      (builtins.attrNames cfg.access)
    }
  '';
in {
  options.nix-bitcoin.onionAddresses = {
    access = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        This option controls who is allowed to access onion hostnames.  For
        example the following allows the user operator to access the bitcoind
        and clightning onion.
        {
          "operator" = [ "bitcoind" "clightning" ];
        };
        The onion hostnames can then be read from
        /var/lib/onion-addresses/<user>.
      '';
    };
  };

  config = mkIf (cfg.access != {}) {
    systemd.services.onion-addresses = {
      wantedBy = [ "tor.service" ];
      bindsTo = [ "tor.service" ];
      after = [ "tor.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = "${pkgs.bash}/bin/bash ${onion-addresses-script}";
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "onion-addresses";
        PrivateNetwork = "true"; # This service needs no network access
        PrivateUsers = "false";
        CapabilityBoundingSet = "CAP_CHOWN CAP_FSETID CAP_SETFCAP CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_IPC_OWNER";
      };
    };
  };
}
