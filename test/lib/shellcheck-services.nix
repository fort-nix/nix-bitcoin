{ config, pkgs, lib, extendModules, ... }:
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

  # TODO-EXTERNAL:
  # This can be removed when https://github.com/NixOS/nixpkgs/pull/189836 is merged.
  #
  # A list of all systemd service definitions and their locations, with format
  # [
  #   {
  #     file = ...;
  #     value = { postgresql = ...; };
  #   }
  #   ...
  # ]
  systemdServiceDefs =
    (extendModules {
      modules = [
        {
          # Currently, NixOS modules only allow accessing option definition locations
          # via type.merge.
          # Override option `systemd.services` and use it to return the list of service defs.
          options.systemd.services = lib.mkOption {
            type = lib.types.anything // {
              merge = loc: defs: defs;
            };
          };

          # Disable all modules that define options.systemd.services so that these
          # defs don't collide with our definition
          disabledModules = [
            "system/boot/systemd.nix"
            # These files amend option systemd.services
            "testing/service-runner.nix"
            "security/systemd-confinement.nix"
          ];

          config._module.check = false;
        }
      ];
    }).config.systemd.services;

  # A list of all service names that are defined by nix-bitcoin.
  # [ "bitcoind", "clightning", ... ]
  #
  # Algorithm: Parse `systemdServiceDefs` and return all services that
  # only have definitions located in the nix-bitcoin source.
  nix-bitcoin-services = let
    nix-bitcoin-source = toString ../..;
    nbServices = collectServices true;
    nonNbServices = collectServices false;
    # Return set of services ({ service1 = true; service2 = true; ... })
    # which are either defined or not defined by nix-bitcoin, depending
    # on `fromNixBitcoin`.
    collectServices = fromNixBitcoin: lib.listToAttrs (builtins.concatLists (map (def:
      let
        isNbSource = lib.hasPrefix nix-bitcoin-source def.file;
      in
        # Nix has nor boolean XOR, so use `if`
        lib.optionals (if fromNixBitcoin then isNbSource else !isNbSource) (
          (map (service: { name = service; value = true; }) (builtins.attrNames def.value))
        )
    ) systemdServiceDefs));
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
