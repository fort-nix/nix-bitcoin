{ config, pkgs, lib, extendModules, ... }@args:
with lib;
let
  options = {
    test.shellcheckServices = mkOption {
      readOnly = true;
      description = ''
        A derivation that runs shellcheck on all bash scripts included
        in nix-bitcoin services.
      '';
      default = shellcheckServices;
    };
  };

  # A list of all service names that are defined by nix-bitcoin.
  # [ "bitcoind", "clightning", ... ]
  #
  # Algorithm: Parse defintions of `systemd.services` and return all services
  # that only have definitions located in the nix-bitcoin source.
  nix-bitcoin-services = let
    systemdServices = args.options.systemd.services;
    nix-bitcoin-source = toString ../..;
    nbServices = collectServices true;
    nonNbServices = collectServices false;
    # Return set of services ({ service1 = true; service2 = true; ... })
    # which are either defined or not defined by nix-bitcoin, depending
    # on `fromNixBitcoin`.
    collectServices = fromNixBitcoin: lib.listToAttrs (builtins.concatLists (zipListsWith (services: file:
      let
        isNbSource = lib.hasPrefix nix-bitcoin-source file;
      in
        # Nix has no boolean XOR, so use `if`
        lib.optionals (if fromNixBitcoin then isNbSource else !isNbSource) (
          (map (service: { name = service; value = true; }) (builtins.attrNames services))
        )
    # TODO-EXTERNAL:
    # Use `systemdServices.definitionsWithLocations` when https://github.com/NixOS/nixpkgs/pull/189836
    # is included in nixpkgs stable.
    ) systemdServices.definitions systemdServices.files));
  in
    # Set difference: nbServices - nonNbServices
    builtins.filter (nbService: ! nonNbServices ? ${nbService}) (builtins.attrNames nbServices);

  # The concatenated list of values of ExecStart, ExecStop, ... (`scriptAttrs`) of all `nix-bitcoin-services`.
  serviceCmds = let
    scriptAttrs = [
      "ExecStartPre"
      "ExecStart"
      "ExecStartPost"
      "ExecStop"
      "ExecStopPost"
      "ExecCondition"
      "ExecReload"
    ];
    services = config.systemd.services;
  in
    builtins.concatMap (serviceName: let
      serviceCfg = services.${serviceName}.serviceConfig;
    in
      builtins.concatMap (attr:
        lib.optionals (serviceCfg ? ${attr}) (
          let
            cmd = serviceCfg.${attr};
          in
            if builtins.typeOf cmd == "list" then cmd else [ cmd ]
        )
      ) scriptAttrs
    ) nix-bitcoin-services;

  # A list of all binaries included in `serviceCmds`
  serviceBinaries = map (cmd: builtins.head (
    # Extract the first component (the binary).
    # cmd can start with extra modifiers like `+`
    builtins.match "[^/]*([^[:space:]]+).*" (toString cmd)
  )) serviceCmds;

  shellcheckServices = pkgs.runCommand "shellcheck-services" {
    inherit serviceBinaries;
    # The `builtins.match` in `serviceBinaries` discards the string context, so we
    # also have to add `serviceCmds` to the derivation. This ensures that all
    # referenced nix paths are available to the builder.
    inherit serviceCmds;
  } ''
    echo "Checked binaries:"
    # Find and check all binaries that have a bash shebang
    grep -Pl '\A#! *\S+bash\b' $serviceBinaries | while IFS= read -r script; do
      echo "$script"
      ${pkgs.shellcheck}/bin/shellcheck --shell bash "$script"
    done | tee "$out"
  '';
in
{
  inherit options;
}
