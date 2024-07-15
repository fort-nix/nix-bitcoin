{ config, pkgs, lib, ... }:

# Create a WireGuard server with a single peer.
# Private/public keys are created via the secrets system.
# Add helper binaries `nix-bitcoin-wg-connect` and optionally `lndconnect-wg`, `lndconnect-clightning-wg`.

# See ../../docs/services.md ("Use Zeus (mobile lightning wallet) via WireGuard")
# for usage instructions.

# This is a rather opinionated implementation that lacks the flexibility offered by
# other nix-bitcoin modules, so ship this as a `preset`.
# Some users will prefer to use `lndconnect` with their existing WireGuard or Tailscale setup.

with lib;
let
  options.nix-bitcoin.wireguard = {
    subnet = mkOption {
      type = types.str;
      default = "10.10.0";
      description = "The /24 subnet of the wireguard network.";
    };
    restrictPeer = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Prevent the peer from connecting to any addresses except for the WireGuard server address.
      '';
    };
  };

  cfg = config.nix-bitcoin.wireguard;
  wgSubnet = cfg.subnet;
  inherit (config.networking.wireguard.interfaces) wg-nb;
  inherit (config.services)
    lnd
    clightning-rest;

  lndconnect = lnd.enable && lnd.lndconnect.enable;
  lndconnect-clightning = clightning-rest.enable && clightning-rest.lndconnect.enable;

  serverAddress = "${wgSubnet}.1";
  peerAddress = "${wgSubnet}.2";

  secretsDir = config.nix-bitcoin.secretsDir;

  wgConnectUser = if config.nix-bitcoin.operator.enable
                  then config.nix-bitcoin.operator.name
                  else "root";

  # A script that prints a QR code to connect a peer to the server.
  # The QR code encodes a wg-quick config that can be imported by the wireguard
  # mobile app.
  wgConnect = pkgs.writers.writeBashBin "nix-bitcoin-wg-connect" ''
    set -euo pipefail
    text=
    host=
    for arg in "$@"; do
      case $arg in
        --text)
          text=1
          ;;
        *)
          host=$arg
          ;;
      esac
    done

    if [[ ! $host ]]; then
      # Use lndconnect to fetch the external ip.
      # This internally uses https://github.com/GlenDC/go-external-ip, which
      # queries a set of external ip providers.
      host=$(
        ${getExe config.nix-bitcoin.pkgs.lndconnect} --url --nocert \
          --configfile=/dev/null --adminmacaroonpath=/dev/null \
          | sed -nE 's|.*?/(.*?):.*|\1|p'
      )
    fi

    config="[Interface]
    PrivateKey = $(cat ${secretsDir}/wg-peer-private-key)
    Address = ${peerAddress}/24

    [Peer]
    PublicKey = $(cat ${secretsDir}/wg-server-public-key)
    AllowedIPs = ${wgSubnet}.0/24
    Endpoint = $host:${toString wg-nb.listenPort}
    PersistentKeepalive = 25
    "

    if [[ $text ]]; then
      echo "$config"
    else
      echo "$config" | ${getExe pkgs.qrencode} -t UTF8 -o -
    fi
  '';
in {
  inherit options;

  config = {
    assertions = [
      {
        # Don't support `netns-isolation` for now to keep things simple
        assertion = !(config.nix-bitcoin.netns-isolation.enable or false);
        message = "`nix-bitcoin.wireguard` is not compatible with `netns-isolation`.";
      }
    ];

    networking.wireguard.interfaces.wg-nb = {
      ips = [ "${serverAddress}/24" ];
      listenPort = mkDefault 51820;
      privateKeyFile = "${secretsDir}/wg-server-private-key";
      allowedIPsAsRoutes = false;
      peers = [
        {
          # To use the actual public key from the secrets file, use dummy pubkey
          # `peer0` and replace it via `getPubkeyFromFile` (see further below)
          # at peer service runtime.
          publicKey = "peer0";
          allowedIPs = [ "${peerAddress}/32" ];
        }
      ];
    };

    systemd.services = {
      wireguard-wg-nb = rec {
        wants = [ "nix-bitcoin-secrets.target" ];
        after = wants;
      };

      # HACK: Modify start/stop scripts of the peer setup service to read
      # the pubkey from a secrets file.
      wireguard-wg-nb-peer-peer0 = let
        getPubkeyFromFile = mkBefore ''
          if [[ ! -v inPatchedSrc ]]; then
            export inPatchedSrc=1
            publicKey=$(cat "${secretsDir}/wg-peer-public-key")
            <"''${BASH_SOURCE[0]}" sed "s|\bpeer0\b|$publicKey|g" | ${pkgs.bash}/bin/bash -s
            exit
          fi
        '';
      in {
        script = getPubkeyFromFile;
        postStop = getPubkeyFromFile;
      };
    };

    environment.systemPackages = [
      wgConnect
    ] ++ (optional lndconnect
      (pkgs.writers.writeBashBin "lndconnect-wg" ''
        exec lndconnect --host "${serverAddress}" --nocert "$@"
      '')
    ) ++ (optional lndconnect-clightning
      (pkgs.writers.writeBashBin "lndconnect-clightning-wg" ''
        exec lndconnect-clightning --host "${serverAddress}" --nocert "$@"
      '')
    );

    networking.firewall = let
      restrictPeerRule = "-s ${peerAddress} ! -d ${serverAddress} -j REJECT";
    in {
      allowedUDPPorts = [ wg-nb.listenPort ];

      extraCommands =
        optionalString lndconnect ''
          iptables -w -A nixos-fw -p tcp -s ${wgSubnet}.0/24 --dport ${toString lnd.restPort} -j nixos-fw-accept
        ''
        + optionalString lndconnect-clightning ''
          iptables -w -A nixos-fw -p tcp -s ${wgSubnet}.0/24 --dport ${toString clightning-rest.port} -j nixos-fw-accept
        ''
        + optionalString cfg.restrictPeer ''
          iptables -w -A nixos-fw ${restrictPeerRule}
          iptables -w -A FORWARD ${restrictPeerRule}
        '';

      extraStopCommands =
        # Rules added to chain `nixos-fw` are automatically removed when restarting
        # the NixOS firewall service.
        mkIf cfg.restrictPeer ''
          iptables -w -D FORWARD ${restrictPeerRule} || :
        '';
    };

    # Listen on all addresses, including `serverAddress`.
    # This is safe because the listen ports are secured by the firewall.
    services.lnd = mkIf lndconnect {
      restAddress = "0.0.0.0";
      tor.enforce = false;
    };
    services.clightning-rest = mkIf lndconnect-clightning {
      # clightning-rest always listens on "0.0.0.0"
      tor.enforce = false;
    };

    nix-bitcoin.secrets = {
      wg-server-private-key = {};
      wg-server-public-key = { user = wgConnectUser; group = "root"; };
      wg-peer-private-key = { user = wgConnectUser; group = "root"; };
      wg-peer-public-key = {};
    };

    nix-bitcoin.generateSecretsCmds.wireguard = let
      wg = "${pkgs.wireguard-tools}/bin/wg";
    in ''
      makeWireguardKey() {
        local name=$1
        local priv=wg-$name-private-key
        local pub=wg-$name-public-key
        if [[ ! -e $priv ]]; then
          ${wg} genkey > $priv
        fi
        if [[ $priv -nt $pub ]]; then
          ${wg} pubkey < $priv > $pub
        fi
      }
      makeWireguardKey server
      makeWireguardKey peer
    '';
  };
}
