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
      default = 1;
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
      default = config.nix-bitcoin.operator.name;
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
      source = config.nix-bitcoin.pkgs.netns-exec;
      capabilities = "cap_sys_admin=ep";
      owner = cfg.allowedUser;
      permissions = "550";
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
          RemainAfterExit = true;
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
        allowedAddresses = concatMapStringsSep "," (available: netns.${available}.address) v.availableNetns;
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
          '' + optionalString (config.services.${n}.enforceTor or false) ''
            ${netnsIptables} -w -P OUTPUT DROP
            ${netnsIptables} -w -A OUTPUT -d 127.0.0.1,${bridgeIp},${v.address} -j ACCEPT
          '' + optionalString (v.availableNetns != []) ''
            ${netnsIptables} -w -A INPUT -s ${allowedAddresses} -j ACCEPT
            ${netnsIptables} -w -A OUTPUT -d ${allowedAddresses} -j ACCEPT
          '';
          # Link deletion is implicit in netns deletion, but it sometimes only happens
          # after `netns delete` finishes. Add an extra `link del` to ensure that
          # the link is deleted before the service stops, which is needed for service
          # restart to succeed.
          preStop = ''
            ${ip} netns delete ${netnsName}
            ${ip} link del ${peer} 2> /dev/null || true
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
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
      nbxplorer = {
        id = 23;
        connections = [ "bitcoind" ];
      };
      btcpayserver = {
        id = 24;
        connections = [ "nbxplorer" ]
                      ++ optional (config.services.btcpayserver.lightningBackend == "lnd") "lnd";
        # communicates with clightning over rpc socket
      };
      joinmarket = {
        id = 25;
        connections = [ "bitcoind" ];
      };
      joinmarket-ob-watcher = {
        id = 26;
      };
      lightning-pool = {
        id = 27;
        connections = [ "lnd" ];
      };
    };

    services.bitcoind = {
      address = netns.bitcoind.address;
      rpc.address = netns.bitcoind.address;
      rpc.allowip = [
        bridgeIp # For operator user
        netns.bitcoind.address
      ] ++ map (n: netns.${n}.address) netns.bitcoind.availableNetns;
    };
    systemd.services.bitcoind-import-banlist.serviceConfig.NetworkNamespacePath = "/var/run/netns/nb-bitcoind";

    services.clightning.address = netns.clightning.address;

    services.lnd = {
      address = netns.lnd.address;
      rpcAddress = netns.lnd.address;
      restAddress = netns.lnd.address;
    };

    services.liquidd = {
      address = netns.liquidd.address;
      rpc.address = netns.liquidd.address;
      rpcallowip = [
        bridgeIp # For operator user
        netns.liquidd.address
      ] ++ map (n: netns.${n}.address) netns.liquidd.availableNetns;
    };

    services.electrs.address = netns.electrs.address;

    services.spark-wallet = {
      address = netns.spark-wallet.address;
      extraArgs = "--no-tls";
    };

    services.lightning-loop.rpcAddress = netns.lightning-loop.address;

    services.nbxplorer.address = netns.nbxplorer.address;
    services.btcpayserver.address = netns.btcpayserver.address;

    services.joinmarket.cliExec = mkCliExec "joinmarket";
    systemd.services.joinmarket-yieldgenerator.serviceConfig.NetworkNamespacePath = "/var/run/netns/nb-joinmarket";

    services.joinmarket-ob-watcher.address = netns.joinmarket-ob-watcher.address;

    services.lightning-pool.rpcAddress = netns.lightning-pool.address;
  }
  ]);
}
