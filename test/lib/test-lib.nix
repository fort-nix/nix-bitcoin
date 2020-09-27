{ config, lib, ... }:
with lib;
{
  options = {
    test = {
      noConnections = mkOption {
        type = types.bool;
        default = true;
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
          dictionary variable 'test_data'. The data is exported via JSON.
        '';
      };
    };

    tests = mkOption {
      type = with types; attrsOf bool;
      default = {};
      description = "Python tests that should be run.";
    };
  };
}
