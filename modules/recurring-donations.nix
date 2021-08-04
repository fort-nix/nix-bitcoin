{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.recurring-donations;
  nbLib = config.nix-bitcoin.lib;
  recurring-donations-script = pkgs.writeScript "recurring-donations.sh" ''
    LNCLI="${config.nix-bitcoin.pkgs.clightning}/bin/lightning-cli --lightning-dir=${config.services.clightning.dataDir}"
    pay_tallycoin() {
      NAME=$1
      AMOUNT=$2
      echo Attempting to pay $AMOUNT sat to $NAME
      INVOICE=$(curl --socks5-hostname ${config.nix-bitcoin.torClientAddressWithPort} -d "satoshi_amount=$AMOUNT&payment_method=ln&id=$NAME&type=profile" -X POST https://api.tallyco.in/v1/payment/request/ | jq -r '.lightning_pay_request') 2> /dev/null
      if [ -z "$INVOICE" ] || [ "$INVOICE" = "null" ]; then
        echo "ERROR: did not get invoice from tallycoin"
        return
      fi
      # Decode invoice and compare amount with requested amount
      DECODED_AMOUNT=$($LNCLI decodepay "$INVOICE" | jq -r '.amount_msat' | head -c -8)
      if [ -z "$DECODED_AMOUNT" ] || [ "$DECODED_AMOUNT" = "null" ]; then
        echo "ERROR: did not get response from clightning"
        return
      fi
      if [ $DECODED_AMOUNT -eq $AMOUNT ]; then
        echo Paying with invoice "$INVOICE"
        $LNCLI pay "$INVOICE"
      else
        echo ERROR: requested amount and invoice amount do not match. $AMOUNT vs $DECODED_AMOUNT
        return
      fi
    }
    ${ builtins.foldl'
      (x: receiver: x +
        ''
        pay_tallycoin ${receiver} ${toString (builtins.getAttr receiver cfg.tallycoin)}
        '')
      ""
      (builtins.attrNames cfg.tallycoin)
    }
  '';
in {
  options.services.recurring-donations = {
    enable = mkEnableOption "recurring-donations";
    tallycoin = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        This option is used to specify tallycoin donation receivers using an
        attribute set.  For example the following setting instructs the module
        to repeatedly send 1000 satoshis to djbooth007.
        {
          "djbooth007" = 1000;
        }
      '';
    };
    interval = mkOption {
      type = types.str;
      default = "Mon *-*-* 00:00:00";
      description = ''
        Schedules the donations. Default is weekly on Mon 00:00:00. See `man
        systemd.time` for further options.
      '';
    };
    randomizedDelaySec = mkOption {
      type = types.int;
      default = 86400;
      description = ''
        Random delay to add to scheduled time for donation. Default is one day.
      '';
    };
    enforceTor = nbLib.enforceTor;
  };

  config = mkIf cfg.enable {
    services.clightning.enable = true;

    systemd.services.recurring-donations = {
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      path = with pkgs; [ nix-bitcoin.clightning curl jq ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${pkgs.bash}/bin/bash ${recurring-donations-script}";
        User = "recurring-donations";
        Type = "oneshot";
      } // nbLib.allowedIPAddresses cfg.enforceTor;
    };
    systemd.timers.recurring-donations = {
      requires = [ "clightning.service" ];
      after = [ "clightning.service" ];
      timerConfig = {
        Unit = "recurring-donations.service";
        OnCalendar = cfg.interval;
        RandomizedDelaySec = toString cfg.randomizedDelaySec;
      };
      wantedBy = [ "multi-user.target" ];
    };

    users.users.recurring-donations = {
      isSystemUser = true;
      group = "recurring-donations";
      extraGroups = [ config.services.clightning.group ];
    };
    users.groups.recurring-donations = {};
  };
}
