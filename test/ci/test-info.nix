pkgs: instantiateTests:

let
  # `instantiateTests` prints the test name before evaluating, which is useful for debugging
  ciTests = instantiateTests [
    "default"
    "netns"
    "netnsRegtest"
  ];
  drivers = map (x: x.driver) ciTests;
  driverDrvs = map (x: ''"${x.drvPath}^*"'') drivers;
in ''
driverDrvs=(
${builtins.concatStringsSep "\n" driverDrvs}
)
drivers=(
${builtins.concatStringsSep "\n" drivers}
)
scenarioTests=(
${builtins.concatStringsSep "\n" ciTests}
)
''
