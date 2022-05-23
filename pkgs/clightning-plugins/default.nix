pkgs: nbPython3Packages:

let
  inherit (pkgs) lib;

  src = pkgs.fetchFromGitHub {
    owner = "lightningd";
    repo = "plugins";
    rev = "7ef9e6c172c0bd0dd09168e19b29e44f7ec6ec4d";
    sha256 = "12llf4dnyria0s1x4bmm360d6bxk47z0wyxwwlmq3762mdfl36js";
  };

  version = builtins.substring 0 7 src.rev;

  plugins = with nbPython3Packages; {
    helpme = { description = "Walks you through setting up a c-lightning node, offering advice for common problems"; };
    monitor = {
      description = "Helps you analyze the health of your peers and channels";
      extraPkgs = [ packaging ];
    };
    prometheus = {
      description = "Lightning node exporter for the prometheus timeseries server";
      extraPkgs = [ prometheus_client ];
      patchRequirements =
        "--replace prometheus-client==0.6.0 prometheus-client==0.11.0"
        + " --replace pyln-client~=0.9.3 pyln-client~=0.10.1";
    };
    rebalance = { description = "Keeps your channels balanced"; };
    commando = {
      description = "Enable RPC over lightning";
      extraPkgs = [ nbPython3Packages.runes ];
    };
    summary = {
      description = "Prints a summary of the node status";
      extraPkgs = [ packaging requests ];
    };
    zmq = {
      description = "Publishes notifications via ZeroMQ to configured endpoints";
      scriptName = "cl-zmq";
      extraPkgs = [ twisted txzmq ];
    };
  };

  basePkgs = [ nbPython3Packages.pyln-client ];

  mkPlugin = name: plugin: let
    python = pkgs.python3.withPackages (_: basePkgs ++ (plugin.extraPkgs or []));
    script = "${plugin.scriptName or name}.py";
    drv = pkgs.stdenv.mkDerivation {
      pname = "clightning-plugin-${name}";
      inherit version;

      buildInputs = [ python ];

      buildCommand = ''
        cp --no-preserve=mode -r ${src}/${name} $out
        cd $out
        ${lib.optionalString (plugin ? patchRequirements) ''
          substituteInPlace requirements.txt ${plugin.patchRequirements}
        ''}

        # Check that requirements are met
        PYTHONPATH=${toString python}/${python.sitePackages} \
          ${pkgs.python3Packages.pip}/bin/pip install -r requirements.txt --no-cache --no-index

        chmod +x ${script}
        patchShebangs ${script}
      '';

      passthru.path = "${drv}/${script}";

      meta = with lib; {
        inherit (plugin) description;
        homepage = "https://github.com/lightningd/plugins";
        license = licenses.bsd3;
        maintainers = with maintainers; [ nixbitcoin earvstedt ];
        platforms = platforms.unix;
      };
    };
  in drv;

in
  builtins.mapAttrs mkPlugin plugins
