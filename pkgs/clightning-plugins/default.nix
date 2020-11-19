pkgs: nbPython3Packages:

let
  inherit (pkgs) lib;

  src = pkgs.fetchFromGitHub {
    owner = "lightningd";
    repo = "plugins";
    rev = "6cd472636926f05a9c472139fabe1ff11c90aa6a";
    sha256 = "1lisx85vzsfzjhdc6zdz0l6bcrdgg6rp5xbc5jmx93mv8qqg2cns";
  };

  version = builtins.substring 0 7 src.rev;

  plugins = with nbPython3Packages; {
    helpme = {};
    monitor = {};
    prometheus = {
      extraPkgs = [ prometheus_client ];
      patchRequirements = "--replace prometheus-client==0.6.0 prometheus-client==0.8.0";
    };
    rebalance = {};
    summary = {
      extraPkgs = [ packaging requests ];
    };
    zmq = {
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
    };
  in drv;

in
  builtins.mapAttrs mkPlugin plugins
