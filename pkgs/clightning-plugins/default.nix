pkgs: nbPython3Packages:

let
  inherit (pkgs) lib;

  src = pkgs.fetchFromGitHub {
    owner = "lightningd";
    repo = "plugins";
    rev = "83a80d134ecb2adc6647235d56195332e846f5cb";
    sha256 = "1vwsvrak2jkcdfcaj426z4qk8shpkqhrqlfnb9i43w24ry7sqzy1";
  };

  version = builtins.substring 0 7 src.rev;

  plugins = with nbPython3Packages; {
    currencyrate = {
      description = "Currency rate fetcher and converter";
      extraPkgs = [ requests cachetools ];
    };
    feeadjuster = {
      description = "Dynamically changes channel fees to keep your channels more balanced";
    };
    monitor = {
      description = "Helps you analyze the health of your peers and channels";
      extraPkgs = [ packaging ];
    };
    rebalance = {
      description = "Keeps your channels balanced";
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
