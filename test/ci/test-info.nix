pkgs: instantiateTests:

let
  scenarioNames = let
    inherit (pkgs) lib;
    workflowSrc = builtins.readFile ../../.github/workflows/test.yml;
    matches = builtins.match ".*scenario:(([ \n]+-[ ]+[^ \n]+)+).*" workflowSrc;
    scenariosStr = builtins.head matches;
    particles = builtins.split "[ \n]+-[ ]+" scenariosStr;
    # The first split particle is always an empty str
    particles' = builtins.tail particles;
  in
    builtins.filter lib.isString particles';

  # `instantiateTests` prints the test name before evaluating, which is useful for debugging
  ciTests = instantiateTests scenarioNames;
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
