{ config, lib, ... }:
with lib;
{
  imports = [
    ./shellcheck-services.nix
  ];

  options = {
    test = {
      noConnections = mkOption {
        type = types.bool;
        default = !config.test.container.enableWAN;
        description = ''
          Whether services should be configured to not connect to external hosts.
          This can silence some warnings while running the test in an offline environment.
        '';
      };
      data = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Attrs that are available in the Python test script under the global
          dictionary variable {var}`test_data`. The data is exported via JSON.
        '';
      };
      extraTestScript = mkOption {
        type = types.lines;
        default = "";
        description = "Extra lines added to the Python test script.";
      };
      container = {
        # Forwarded to extra-container. For descriptions, see
        # https://github.com/erikarvstedt/extra-container/blob/master/eval-config.nix
        addressPrefix = mkOption { default = "10.225.255"; };
        enableWAN = mkOption { default = false; };
        firewallAllowHost = mkOption { default = true; };
        exposeLocalhost = mkOption { default = false; };
      };
    };

    tests = mkOption {
      type = with types; attrsOf bool;
      default = {};
      description = "Python tests that should be run.";
    };
  };
}
