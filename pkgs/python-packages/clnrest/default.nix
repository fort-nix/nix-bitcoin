{ buildPythonPackageWithDepsCheck
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
  self = buildPythonPackageWithDepsCheck rec {
    pname = "clnrest";
    version = clightning.version;
    format = "pyproject";

    inherit (clightning) src;

    postUnpack = "sourceRoot=$sourceRoot/plugins/clnrest";

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace 'gevent = "^23.9.0.post1"' 'gevent = "22.10.2"'

      sed -i '/authors/a include = [ { path = "utilities", format = ["sdist", "wheel"] } ]' pyproject.toml
    '';

    nativeBuildInputs = [ poetry-core ];

    propagatedBuildInputs = [
      flask
      flask-cors
      flask-restx
      flask-socketio
      gevent
      gevent-websocket
      gunicorn
      pyln-client
      json5
      jsonschema
    ];

    postInstall = ''
      makeWrapper ${python}/bin/python $out/bin/clnrest \
        --set NIX_PYTHONPATH ${python.pkgs.makePythonPath self.propagatedBuildInputs} \
        --add-flags "$out/lib/${python.libPrefix}/site-packages/clnrest.py"
    '';
  };
in
  self
