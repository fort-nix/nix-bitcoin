{ buildPythonPackage
, clightning
, python
, poetry-core
, flask
, flask-cors
, flask-restx
, flask-socketio
, gevent
, gevent-websocket
, gunicorn
, pyln-client
, json5
, jsonschema
}:

let
  self = buildPythonPackage rec {
    pname = "clnrest";
    version = clightning.version;
    format = "pyproject";

    inherit (clightning) src;

    postUnpack = "sourceRoot=$sourceRoot/plugins/clnrest";

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace 'gevent = "^23.9.0.post1"' 'gevent = "24.2.1"' \
        --replace 'flask = "^2.3.3"' 'flask = "3.0.3"'

      # Add extra required src files that are missing in pyproject.toml
      sed -i '/authors/a include = [ { path = "utilities", format = ["sdist", "wheel"] } ]' pyproject.toml
    '';

    nativeBuildInputs = [ poetry-core ];

    # From https://github.com/ElementsProject/lightning/blob/master/plugins/clnrest/pyproject.toml
    propagatedBuildInputs = [
      flask
      flask-cors
      flask-restx
      flask-socketio
      gevent
      gevent-websocket
      gunicorn
      json5
      pyln-client
    ];

    postInstall = ''
      makeWrapper ${python}/bin/python $out/bin/clnrest \
        --set NIX_PYTHONPATH ${python.pkgs.makePythonPath self.propagatedBuildInputs} \
        --add-flags "$out/lib/${python.libPrefix}/site-packages/clnrest.py"
    '';
  };
in
  self
