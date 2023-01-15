{ pkgs, lib, scenarios, nix-bitcoin }:
with lib;
rec {
  # For more examples, see `scenarios` and `exampleScenarios` in ./src/test/tests.nix

  template = { config, pkgs, lib, ... }: {
    imports = [
      (nix-bitcoin + "/modules/presets/secure-node.nix")
      scenarios.netnsBase
      scenarios.regtestBase
    ];
    test.container.enableWAN = true;
    test.container.exposeLocalhost = true;
  };

  myscenario = { config, pkgs, lib, ... }: {
    services.clightning.enable = true;
    nix-bitcoin.nodeinfo.enable = true;
  };
}
