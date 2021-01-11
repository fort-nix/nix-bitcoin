{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.nix-bitcoin-org;
  nbLib = config.nix-bitcoin.lib;
  indexFile = ./index.html;
  devkeys = ./devkeys.html;
  files = ./files;
  createWebsite = pkgs.writeText "make-index.sh" ''
    set -e
    cp ${indexFile} /var/www/index.html
    cp ${devkeys} /var/www/devkeys.html
    cp ${files}/* /var/www/files
    chown -R nginx:nginx /var/www/
  '';
in {
  options.services.nix-bitcoin-org = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nix-bitcoin.org service will be installed.
      '';
    };
    host = mkOption {
      type = types.str;
      default = if config.nix-bitcoin.netns-isolation.enable then
        config.nix-bitcoin.netns-isolation.netns.nginx.address
      else
        "localhost";
      description = "HTTP server listen address.";
    };
  };

  config = mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /var/www 0750 nginx nginx - -"
      "d /var/www/files 0750 nginx nginx - -"
    ];

    networking.nat = {
      enable = true;
      externalInterface = "enp2s0";
      forwardPorts = [
        {
          destination = "169.254.1.21:80";
          proto = "tcp";
          sourcePort = 80;
        }
        {
          destination = "169.254.1.21:443";
          proto = "tcp";
          sourcePort = 443;
        }
      ];
    };
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    nix-bitcoin.netns-isolation.services.btcpayserver.connections = [ "nginx" ];
    nix-bitcoin.netns-isolation.services.joinmarket-ob-watcher.connections = [ "nginx" ];
    # Allow connections from outside netns
    systemd.services.nginx.serviceConfig = {
      ExecStartPost = "${nbLib.privileged "nginx-netns-hop" ''
        ${pkgs.iproute}/bin/ip netns exec nb-nginx ${config.networking.firewall.package}/bin/iptables -A INPUT -p TCP --dport 80 -j ACCEPT
        ${pkgs.iproute}/bin/ip netns exec nb-nginx ${config.networking.firewall.package}/bin/iptables -A INPUT -p TCP --dport 443 -j ACCEPT
      ''}";
    };

    security.acme = {
      email = "nixbitcoin@i2pmail.org";
      acceptTerms = true;
    };
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      commonHttpConfig = ''
        # Disable the access log for user privacy
        access_log off;
      '';
      virtualHosts."nixbitcoin.org" = {
        forceSSL = true;
        root = "/var/www";
        enableACME = true;
        locations."/btcpayserver/" = {
          proxyPass = "http://169.254.1.24:23000";
        };
        extraConfig = ''
          location /obwatcher/ {
            proxy_pass http://${toString config.services.joinmarket-ob-watcher.address}:${toString config.services.joinmarket-ob-watcher.port};
            rewrite /obwatcher/(.*) /$1 break;
          }
          add_header Onion-Location http://qvzlxbjvyrhvsuyzz5t63xx7x336dowdvt7wfj53sisuun4i4rdtbzid.onion$request_uri;
        '';
      };
      virtualHosts."_" = {
        root = "/var/www";
        locations."/btcpayserver/" = {
          proxyPass = "http://169.254.1.24:23000";
        };
        extraConfig = ''
          location /obwatcher/ {
            proxy_pass http://${toString config.services.joinmarket-ob-watcher.address}:${toString config.services.joinmarket-ob-watcher.port};
            rewrite /obwatcher/(.*) /$1 break;
          }
        '';
      };
    };
    systemd.services."acme-nixbitcoin.org".serviceConfig.NetworkNamespacePath = "/var/run/netns/nb-nginx";

    services.btcpayserver.rootpath = "btcpayserver";

    services.tor.hiddenServices.nginx = {
      map = [{
        port = 80; toHost = cfg.host;
      } {
        port = 443; toHost = cfg.host;
      }];
      version = 3;
    };

    systemd.services.create-webpage = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = nbLib.defaultHardening // {
        ExecStart="${pkgs.bash}/bin/bash ${createWebsite}";
        User = "root";
        Type = "simple";
        RemainAfterExit="yes";
        Restart = "on-failure";
        RestartSec = "10s";
        PrivateNetwork = "true"; # This service needs no network access
        PrivateUsers = "false";
        ReadWritePaths = "/var/www";
        CapabilityBoundingSet = "CAP_SETUID CAP_SETGID CAP_SETPCAP CAP_SYS_ADMIN CAP_CHOWN CAP_FSETID CAP_SETFCAP CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FOWNER CAP_IPC_OWNER";
      };
    };
  };
}
