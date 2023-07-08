pkgs: nbPython3Packages:

let
  inherit (pkgs) lib;

  src = pkgs.applyPatches {
    src = pkgs.fetchFromGitHub {
      owner = "lightningd";
      repo = "plugins";
      rev = "eee5e90df442586b7f891df4fc0c67d273534737";
      sha256 = "0ry6gxp9gqpzpdjykx0a5q53saai5jydwvcy6smsh0f5dmjl8srh";
    };

    patches = [
      # https://github.com/lightningd/plugins/pull/451
      (pkgs.fetchpatch {
        name = "202305-prometheus-msat-purge";
        url = "https://github.com/lightningd/plugins/commit/f8a27b97a1b9ded8790c1f033b1f4268c0a6e210.patch";
        sha256 = "sha256-0lFMhHHIi9bUU0+xaHhpnascNlFmr51JxE6e2F0s0zc=";
      })
    ];
  };

  version = builtins.substring 0 7 src.src.rev;

  plugins = with nbPython3Packages; {
    currencyrate = {
      description = "Currency rate fetcher and converter";
      extraPkgs = [ requests cachetools ];
    };
    feeadjuster = {
      description = "Dynamically changes channel fees to keep your channels more balanced";
    };
    helpme = {
      description = "Walks you through setting up a c-lightning node, offering advice for common problems";
    };
    monitor = {
      description = "Helps you analyze the health of your peers and channels";
      extraPkgs = [ packaging ];
    };
    prometheus = {
      description = "Lightning node exporter for the prometheus timeseries server";
      extraPkgs = [ prometheus_client ];
      patchRequirements =
        "--replace prometheus-client==0.6.0 prometheus-client==0.16.0"
        + " --replace pyln-client~=0.9.3 pyln-client~=23.02";
    };
    rebalance = {
      description = "Keeps your channels balanced";
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
        cp --no-preserve=mode -r '${src}/${name}' "$out"
        cd "$out"
        ${lib.optionalString (plugin ? patchRequirements) ''
          substituteInPlace requirements.txt ${plugin.patchRequirements}
        ''}

        # Check that requirements are met
        PYTHONPATH='${toString python}/${python.sitePackages}' \
          ${pkgs.python3Packages.pip}/bin/pip install -r requirements.txt --no-cache --no-index --break-system-packages

        chmod +x '${script}'
        patchShebangs '${script}'
      '';

      passthru.path = "${drv}/${script}";

      meta = with lib; {
        inherit (plugin) description;
        homepage = "https://github.com/lightningd/plugins";
        license = licenses.bsd3;
        maintainers = with maintainers; [ nixbitcoin erikarvstedt ];
        platforms = platforms.unix;
      };
    };
  in drv;

in
  builtins.mapAttrs mkPlugin plugins
