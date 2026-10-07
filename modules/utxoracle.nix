{ config, lib, pkgs, ... }:

with lib;
let
  options.services.utxoracle = {
    enable = mkEnableOption "UTXOracle Local";

    acceptLicense = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Accept the custom UTXOracle License 1.0.

        UTXOracle is not released under a normal open-source license.
        The license permits consensus-compatible use of UTXOracle Local for
        confirmed-block daily and recent 144-block window prices, and includes
        restrictions on commercial, live, real-time, naming, and branding uses.
        See https://utxo.live/oracle/license.php.
      '';
    };

    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.utxoracle;
      defaultText = "config.nix-bitcoin.pkgs.utxoracle";
      description = "Package providing the {command}`utxoracle` command.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/utxoracle";
      description = ''
        Directory where UTXOracle writes generated HTML output and nix-bitcoin
        writes cached `latest.log`, `latest.html`, and `latest.json` files.
      '';
    };

    user = mkOption {
      type = types.str;
      default = bitcoind.user;
      defaultText = "config.services.bitcoind.user";
      description = ''
        User as which to run UTXOracle.

        UTXOracle reads local Bitcoin Core block files and RPC cookie data, so
        the default is the bitcoind user. This avoids changing bitcoind data
        directory permissions.
      '';
    };

    group = mkOption {
      type = types.str;
      default = bitcoind.group;
      defaultText = "config.services.bitcoind.group";
      description = "Group as which to run UTXOracle.";
    };

    bitcoinDataDir = mkOption {
      type = types.path;
      default = bitcoind.dataDir;
      defaultText = "config.services.bitcoind.dataDir";
      description = "Bitcoin Core data directory used by UTXOracle.";
    };

    calendar = mkOption {
      type = types.str;
      default = "*-*-* 00:45:00 UTC";
      description = ''
        systemd calendar expression for recalculating the confirmed-block
        UTXOracle output.
      '';
    };

    recentBlocks = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Calculate the UTXOracle Block Window Price from the most recent 144
        confirmed blocks instead of the previous UTC day's UTXOracle Consensus
        Price.

        This is a moving confirmed-block estimate, not exchange price data,
        mempool data, or live real-time price data.
      '';
    };

    updateOnBlock = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Recalculate UTXOracle output after Bitcoin Core connects a new block.

        This adds a `blocknotify` command to `services.bitcoind.extraConfig`
        and a systemd path unit that starts `utxoracle.service`. This is most
        useful with `recentBlocks = true`.
      '';
    };

    priceFeed = {
      enable = mkEnableOption "a local cached UTXOracle JSON price feed";

      address = mkOption {
        type = types.enum [ "127.0.0.1" "::1" ];
        default = "127.0.0.1";
        description = ''
          Loopback address for the cached UTXOracle price feed.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 8174;
        description = "Port for the cached UTXOracle price feed.";
      };
    };
  };

  cfg = config.services.utxoracle;
  bitcoind = config.services.bitcoind;
  nbLib = config.nix-bitcoin.lib;

  blockNotifyDir = "${toString cfg.bitcoinDataDir}/utxoracle-blocknotify";

  blockNotifyScript = pkgs.writeShellScriptBin "utxoracle-blocknotify" ''
    set -eu

    notify_dir='${blockNotifyDir}'
    mkdir -p "$notify_dir"

    block_hash="$1"
    printf '%s\n' "$block_hash" > "$notify_dir/latest-block.tmp"
    mv "$notify_dir/latest-block.tmp" "$notify_dir/latest-block"
    touch "$notify_dir/trigger"
  '';

  priceFeed = pkgs.writeTextFile {
    name = "utxoracle-price-feed";
    executable = true;
    destination = "/bin/utxoracle-price-feed";
    text = ''
      #!${pkgs.python3}/bin/python3
      import json
      import os
      from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

      data_dir = os.environ["UTXORACLE_DATA_DIR"]
      listen_address = os.environ["UTXORACLE_PRICE_FEED_ADDRESS"]
      listen_port = int(os.environ["UTXORACLE_PRICE_FEED_PORT"])

      def latest_json():
          path = os.path.join(data_dir, "latest.json")
          with open(path, "r", encoding="utf-8") as f:
              return json.load(f)

      class Handler(BaseHTTPRequestHandler):
          server_version = "utxoracle-price-feed"

          def log_message(self, fmt, *args):
              return

          def send_bytes(self, status, content_type, body):
              self.send_response(status)
              self.send_header("Content-Type", content_type)
              self.send_header("Cache-Control", "no-store")
              self.send_header("Content-Length", str(len(body)))
              self.end_headers()
              self.wfile.write(body)

          def send_json(self, status, payload):
              body = json.dumps(payload, sort_keys=True).encode("utf-8") + b"\n"
              self.send_bytes(status, "application/json; charset=utf-8", body)

          def do_GET(self):
              if self.path in ("/health", "/healthz"):
                  try:
                      latest = latest_json()
                      self.send_json(200, {"ok": True, "has_price": "price_usd" in latest})
                  except Exception as exc:
                      self.send_json(503, {"ok": False, "error": str(exc)})
                  return

              if self.path in ("/", "/latest", "/latest.json", "/price"):
                  try:
                      self.send_json(200, latest_json())
                  except FileNotFoundError:
                      self.send_json(503, {
                          "ok": False,
                          "error": "UTXOracle has not generated latest.json yet",
                      })
                  except Exception as exc:
                      self.send_json(500, {"ok": False, "error": str(exc)})
                  return

              if self.path == "/latest.html":
                  path = os.path.join(data_dir, "latest.html")
                  try:
                      with open(path, "rb") as f:
                          body = f.read()
                  except FileNotFoundError:
                      self.send_json(404, {"ok": False, "error": "latest.html not found"})
                      return
                  self.send_bytes(200, "text/html; charset=utf-8", body)
                  return

              self.send_json(404, {"ok": False, "error": "not found"})

      ThreadingHTTPServer((listen_address, listen_port), Handler).serve_forever()
    '';
  };
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.acceptLicense;
        message = ''
          services.utxoracle requires accepting the custom UTXOracle License 1.0
          via `services.utxoracle.acceptLicense = true`.
          See https://utxo.live/oracle/license.php.
        '';
      }
      {
        assertion = bitcoind.prune == 0;
        message = "UTXOracle needs local block files, so bitcoind pruning must be disabled.";
      }
      {
        assertion = cfg.recentBlocks || !cfg.updateOnBlock;
        message = "services.utxoracle.updateOnBlock is only supported with recentBlocks = true.";
      }
    ];

    services.bitcoind = {
      enable = true;
      extraConfig = mkIf cfg.updateOnBlock ''
        blocknotify=/run/current-system/sw/bin/utxoracle-blocknotify %s
      '';
    };

    environment.systemPackages = [ cfg.package ] ++ optional cfg.updateOnBlock blockNotifyScript;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ] ++ optional cfg.updateOnBlock
      "d '${blockNotifyDir}' 0750 ${cfg.user} ${cfg.group} - -";

    systemd.services.utxoracle = {
      description = "Calculate UTXOracle output from local Bitcoin Core data";
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      path = with pkgs; [ coreutils gnugrep gnused ];
      script = ''
        set -euo pipefail

        export BROWSER=true
        cd '${cfg.dataDir}'

        rm -f latest.log.tmp
        ${cfg.package}/bin/utxoracle -p '${cfg.bitcoinDataDir}' ${optionalString cfg.recentBlocks "-rb"} 2>&1 | tee latest.log.tmp
        mv latest.log.tmp latest.log

        # shellcheck disable=SC2012
        html="$(ls -t UTXOracle_*.html 2>/dev/null | head -n1 || true)"
        if [[ -n "$html" ]]; then
          ln -sfn "$html" latest.html
        fi

        label=""
        price=""
        price_line="$(grep -E 'price: \$[0-9,]+' latest.log | tail -n1 || true)"

        if [[ -n "$price_line" ]]; then
          label="$(printf '%s\n' "$price_line" | sed -E 's/^[[:space:]]*([^$]+) price:.*/\1/')"
          # shellcheck disable=SC2016
          price="$(printf '%s\n' "$price_line" | sed -E 's/.*price: \$([0-9,]+).*/\1/' | tr -d ',')"
        elif [[ -n "$html" ]]; then
          # shellcheck disable=SC2016
          price="$(grep -oE 'UTXOracle Block Window Price \$[0-9,]+' "$html" | tail -n1 | sed -E 's/.*\$([0-9,]+).*/\1/' | tr -d ',' || true)"
          if [[ "$html" =~ UTXOracle_([0-9]+)-([0-9]+)\.html ]]; then
            label="blocks ''${BASH_REMATCH[1]}-''${BASH_REMATCH[2]}"
          else
            label="latest 144 blocks"
          fi
        fi

        if [[ -n "$price" ]]; then
          updated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
          trigger_block_hash="$(cat '${blockNotifyDir}/latest-block' 2>/dev/null || true)"
          cat > latest.json.tmp <<EOF
{
  "name": "${if cfg.recentBlocks then "UTXOracle Block Window Price" else "UTXOracle Consensus Price"}",
  "date": "$label",
  "price_usd": $price,
  "mode": "${if cfg.recentBlocks then "recent_blocks_144" else "24h_confirmed"}",
  "source": "local bitcoin node confirmed blocks",
  "license_scope": "consensus-compatible confirmed-block output",
  "trigger_block_hash": "$trigger_block_hash",
  "updated_at": "$updated_at"
}
EOF
          mv latest.json.tmp latest.json
        fi
      '';
      serviceConfig = nbLib.defaultHardening // {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ReadOnlyPaths = [ cfg.bitcoinDataDir ];
        ReadWritePaths = [ cfg.dataDir ];
      } // nbLib.allowLocalIPAddresses;
    };

    systemd.timers.utxoracle = {
      description = "Run UTXOracle";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.calendar;
        Persistent = true;
        Unit = "utxoracle.service";
      };
    };

    systemd.paths.utxoracle-blocknotify = mkIf cfg.updateOnBlock {
      description = "Run UTXOracle after Bitcoin Core connects a block";
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = blockNotifyDir;
        Unit = "utxoracle.service";
      };
    };

    systemd.services.utxoracle-price-feed = mkIf cfg.priceFeed.enable {
      description = "Serve cached UTXOracle output over local HTTP";
      wantedBy = [ "multi-user.target" ];
      after = [ "utxoracle.service" ];
      environment = {
        UTXORACLE_DATA_DIR = toString cfg.dataDir;
        UTXORACLE_PRICE_FEED_ADDRESS = cfg.priceFeed.address;
        UTXORACLE_PRICE_FEED_PORT = toString cfg.priceFeed.port;
      };
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = "${priceFeed}/bin/utxoracle-price-feed";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        WorkingDirectory = cfg.dataDir;
        ReadOnlyPaths = [ cfg.dataDir ];
      } // nbLib.allowLocalIPAddresses;
    };
  };
}
