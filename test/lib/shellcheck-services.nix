{ config, pkgs, lib, extendModules, ... }@args:
with lib;
let
  options.test.shellcheckServices = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to shellcheck services during system build time.
      '';
    };

    sourcePrefix = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        The definition source path prefix of services to include in the shellcheck.
      '';
    };

    runShellcheck = mkOption {
      readOnly = true;
      description = ''
        A derivation that runs shellcheck on all bash scripts included
        in nix-bitcoin services.
      '';
      default = shellcheckServices;
    };
  };

  cfg = config.test.shellcheckServices;

  # A list of all service names that are defined in source paths prefixed by
  # `sourcePrefix`.
  # [ "bitcoind", "clightning", ... ]
  #
  # Algorithm: Parse defintions of `systemd.services` and return all services
  # that only have definitions located within `sourcePrefix`.
  servicesToCheck = let
    inherit (cfg) sourcePrefix;
    systemdServices = args.options.systemd.services;
    configSystemdServices = args.config.systemd.services;
    matchingServices = collectServices true;
    nonMatchingServices = collectServices false;
    # Return set of services ({ service1 = true; service2 = true; ... })
    # which are either defined or not defined within `sourcePrefix`, depending
    # on `shouldMatch`.
    collectServices = shouldMatch: lib.listToAttrs (builtins.concatLists (map (def:
      let
        services = def.value;
        inherit (def) file;
        isMatching = lib.hasPrefix sourcePrefix file;
      in
        # Nix has no boolean XOR, so use `if`
        lib.optionals (if shouldMatch then isMatching else !isMatching) (
          (map (service: { name = service; value = true; }) (builtins.attrNames services))
        )
    ) systemdServices.definitionsWithLocations));
  in
    # Calculate set difference: matchingServices - nonMatchingServices
    # and exclude unavailable services (defined via `mkIf false ...`) by checking `configSystemdServices`.
    builtins.filter (prefixedService:
      configSystemdServices ? ${prefixedService} && (! nonMatchingServices ? ${prefixedService})
    ) (builtins.attrNames matchingServices);

  # The concatenated list of values of ExecStart, ExecStop, ... (`scriptAttrs`) of all `servicesToCheck`.
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
    ) servicesToCheck;

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

  config = mkIf (cfg.enable && cfg.sourcePrefix != null) {
    assertions = [
      {
        assertion = builtins.length servicesToCheck > 0;
        message = "test.shellcheckServices: No services found with source prefix `${cfg.sourcePrefix}`";
      }
    ];

    system.extraDependencies = [ shellcheckServices ];
  };
}
