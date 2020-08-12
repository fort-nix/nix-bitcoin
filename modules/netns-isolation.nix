{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix-bitcoin.netns-isolation;

  netns = builtins.mapAttrs (n: v: {
    inherit (v) id;
    address = "169.254.${toString cfg.addressblock}.${toString v.id}";
    availableNetns = availableNetns.${n};
    netnsName = "nb-${n}";
  }) enabledServices;

  # Symmetric netns connection matrix
  # if clightning.connections = [ "bitcoind" ]; then
  #   availableNetns.bitcoind = [ "clighting" ];
  #   and
  #   availableNetns.clighting = [ "bitcoind" ];
  #
  # FIXME: Although negligible for our purposes, this calculation's runtime
  # is in the order of (number of connections * number of services),
  # because attrsets and lists are fully copied on each update with '//' or '++'.
  # This can only be improved with an update in the nix language.
  #
  availableNetns = let
    # base = { clightning = [ "bitcoind" ]; ... }
    base = builtins.mapAttrs (n: v:
      builtins.filter isEnabled v.connections
    ) enabledServices;
  in
    foldl (xs: s1:
      foldl (xs: s2:
        xs // { "${s2}" = xs.${s2} ++ [ s1 ]; }
      ) xs cfg.services.${s1}.connections
    ) base (builtins.attrNames base);

  enabledServices = filterAttrs (n: v: isEnabled n) cfg.services;
  isEnabled = x: config.services.${x}.enable;

  ip = "${pkgs.iproute}/bin/ip";
  iptables = "${config.networking.firewall.package}/bin/iptables";

  bridgeIp = "169.254.${toString cfg.addressblock}.10";

  mkCliExec = service: "exec netns-exec ${netns.${service}.netnsName}";
in {
  options.nix-bitcoin.netns-isolation = {
    enable = mkEnableOption "netns isolation";

    addressblock = mkOption {
      type = types.ints.u8;
      default = "1";
      description = ''
        The address block N in 169.254.N.0/24, used as the prefix for netns addresses.
      '';
    };

    services = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            # TODO: Assert uniqueness
            type = types.ints.between 11 255;
            description = ''
              id for the netns, used for the IP address host part and
              for naming the interfaces. Must be unique. Must be greater than 10.
            '';
          };
          connections = mkOption {
            type = with types; listOf str;
            default = [];
          };
        };
      });
    };

    allowedUser = mkOption {
      type = types.str;
      description = ''
        User that is allowed to execute commands in the service network namespaces.
        The user's group is also authorized.
      '';
    };

    netns = mkOption {
      default = netns;
      readOnly = true;
      description = "Exposes netns parameters.";
    };
  };

  config = mkIf cfg.enable (mkMerge [

  # Base infrastructure
  {
    networking.dhcpcd.denyInterfaces = [ "nb-br" "nb-veth*" ];
    services.tor.client.socksListenAddress = "${bridgeIp}:9050";
    networking.firewall.interfaces.nb-br.allowedTCPPorts = [ 9050 ];
    boot.kernel.sysctl."net.ipv4.ip_forward" = true;

    security.wrappers.netns-exec = {
      source = pkgs.nix-bitcoin.netns-exec;
      capabilities = "cap_sys_admin=ep";
      owner = cfg.allowedUser;
      permissions = "u+rx,g+rx,o-rwx";
    };

    systemd.services = {
      # Due to a NixOS bug we can't currently use option `networking.bridges` to
      # setup the bridge while `networking.useDHCP` is enabled.
      nb-netns-bridge = {
        description = "nix-bitcoin netns bridge";
        wantedBy = [ "network-setup.service" ];
        partOf = [ "network-setup.service" ];
        before = [ "network-setup.service" ];
        after = [ "network-pre.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
        };
        script = ''
          ${ip} link add name nb-br type bridge
          ${ip} link set nb-br up
          ${ip} addr add ${bridgeIp}/24 brd + dev nb-br
          ${iptables} -w -t nat -A POSTROUTING -s 169.254.${toString cfg.addressblock}.0/24 -j MASQUERADE
        '';
        preStop = ''
          ${iptables} -w -t nat -D POSTROUTING -s 169.254.${toString cfg.addressblock}.0/24 -j MASQUERADE
          ${ip} link del nb-br
        '';
      };
    } //
    (let
      makeNetnsServices = n: v: let
        veth = "nb-veth-${toString v.id}";
        peer = "nb-veth-br-${toString v.id}";
        inherit (v) netnsName;
        ipNetns = "${ip} -n ${netnsName}";
        netnsIptables = "${ip} netns exec ${netnsName} ${config.networking.firewall.package}/bin/iptables";
      in {
        "${n}".serviceConfig.NetworkNamespacePath = "/var/run/netns/${netnsName}";

        "netns-${n}" = rec {
          requires = [ "nb-netns-bridge.service" ];
          after = [ "nb-netns-bridge.service" ];
          bindsTo = [ "${n}.service" ];
          requiredBy = bindsTo;
          before = bindsTo;
          script = ''
            ${ip} netns add ${netnsName}
            ${ipNetns} link set lo up
            ${ip} link add ${veth} type veth peer name ${peer}
            ${ip} link set ${veth} netns ${netnsName}
            ${ipNetns} addr add ${v.address}/24 dev ${veth}
            ${ip} link set ${peer} up
            ${ipNetns} link set ${veth} up
            ${ip} link set ${peer} master nb-br
            ${ipNetns} route add default via ${bridgeIp}
            ${netnsIptables} -w -P INPUT DROP
            ${netnsIptables} -w -A INPUT -s 127.0.0.1,${bridgeIp},${v.address} -j ACCEPT
            # allow return traffic to outgoing connections initiated by the service itself
            ${netnsIptables} -w -A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
          '' + (optionalString (config.services.${n}.enforceTor or false)) ''
            ${netnsIptables} -w -P OUTPUT DROP
            ${netnsIptables} -w -A OUTPUT -d 127.0.0.1,${bridgeIp},${v.address} -j ACCEPT
          '' + concatMapStrings (otherNetns: let
            other = netns.${otherNetns};
          in ''
            ${netnsIptables} -w -A INPUT -s ${other.address} -j ACCEPT
            ${netnsIptables} -w -A OUTPUT -d ${other.address} -j ACCEPT
          '') v.availableNetns;
          preStop = ''
            ${ip} netns delete ${netnsName}
            ${ip} link del ${peer}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
            ExecStartPre = "-${ip} netns delete ${netnsName}";
          };
        };
      };
    in foldl (services: n:
      services // (makeNetnsServices n netns.${n})
    ) {} (builtins.attrNames netns));
  }

  # Service-specific config
  {
    nix-bitcoin.netns-isolation.services = {
      bitcoind = {
        id = 12;
      };
      clightning = {
        id = 13;
        connections = [ "bitcoind" ];
      };
      lnd = {
        id = 14;
        connections = [ "bitcoind" ];
      };
      liquidd = {
        id = 15;
        connections = [ "bitcoind" ];
      };
      electrs = {
        id = 16;
        connections = [ "bitcoind" ];
      };
      spark-wallet = {
        id = 17;
        # communicates with clightning over lightning-rpc socket
      };
      lightning-charge = {
        id = 18;
        # communicates with clightning over lightning-rpc socket
      };
      nanopos = {
        id = 19;
        connections = [ "nginx" "lightning-charge" ];
      };
      recurring-donations = {
        id = 20;
        # communicates with clightning over lightning-rpc socket
      };
      nginx = {
        id = 21;
      };
      lightning-loop = {
        id = 22;
        connections = [ "lnd" ];
      };
    };

    services.bitcoind = {
      bind = netns.bitcoind.address;
      rpcbind = [
        "${netns.bitcoind.address}"
        "127.0.0.1"
      ];
      rpcallowip = [
        "127.0.0.1"
      ] ++ map (n: "${netns.${n}.address}") netns.bitcoind.availableNetns;
      cli = let
        inherit (config.services.bitcoind) cliBase;
      in pkgs.writeScriptBin cliBase.name ''
        exec netns-exec ${netns.bitcoind.netnsName} ${cliBase}/bin/${cliBase.name} "$@"
      '';
    };
    systemd.services.bitcoind-import-banlist.serviceConfig.NetworkNamespacePath = "/var/run/netns/nb-bitcoind";

    services.clightning = {
      bitcoin-rpcconnect = netns.bitcoind.address;
      bind-addr = netns.clightning.address;
    };

    services.lnd = {
      listen = netns.lnd.address;
      rpclisten = [
        "${netns.lnd.address}"
        "127.0.0.1"
      ];
      restlisten = [
        "${netns.lnd.address}"
        "127.0.0.1"
      ];
      bitcoind-host = netns.bitcoind.address;
      cliExec = mkCliExec "lnd";
    };

    services.liquidd = {
      bind = netns.liquidd.address;
      rpcbind = [
        "${netns.liquidd.address}"
        "127.0.0.1"
      ];
      rpcallowip = [
        "127.0.0.1"
      ] ++ map (n: "${netns.${n}.address}") netns.liquidd.availableNetns;
      mainchainrpchost = netns.bitcoind.address;
      cliExec = mkCliExec "liquidd";
    };

    services.electrs = {
      address = netns.electrs.address;
      daemonrpc = "${netns.bitcoind.address}:${toString config.services.bitcoind.rpc.port}";
    };

    services.spark-wallet = {
      host = netns.spark-wallet.address;
      extraArgs = "--no-tls";
    };

    services.lightning-charge.host = netns.lightning-charge.address;

    services.nanopos = {
      charged-url = "http://${netns.lightning-charge.address}:9112";
      host = netns.nanopos.address;
    };

    services.lightning-loop.cliExec = mkCliExec "lightning-loop";
  }
  ]);
}
