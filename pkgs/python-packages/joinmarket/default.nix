{ version
, src
, lib
, buildPythonPackage
, pythonOlder
, pythonAtLeast
, pytestCheckHook
, setuptools
, fetchurl
, chromalog
, cryptography
, service-identity
, twisted
, txtorcon
, python-bitcointx
, argon2_cffi
, autobahn
, bencoderpyx
, klein
, mnemonic
, pyjwt
, werkzeug
, libnacl
, pyopenssl
}:

buildPythonPackage rec {
  pname = "joinmarket";
  inherit version src;
  format = "pyproject";

  # Since v0.9.11, Python older than v3.8 is not supported. Python v3.12 is
  # still not supported.
  disabled = (pythonOlder "3.8") || (pythonAtLeast "3.12");

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    # base jm packages
    chromalog
    cryptography
    service-identity
    twisted
    txtorcon

    # jmbitcoin
    python-bitcointx

    # jmclient
    argon2_cffi
    autobahn
    bencoderpyx
    klein
    mnemonic
    pyjwt
    werkzeug

    # jmdaemon
    libnacl
    pyopenssl
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'txtorcon==23.11.0' 'txtorcon==23.5.0' \
      --replace-fail 'twisted==23.10.0' 'twisted==23.8.0' \
      --replace-fail 'service-identity==21.1.0' 'service-identity==23.1.0' \
      --replace-fail 'cryptography==41.0.6' 'cryptography==41.0.3'

    # Modify pyproject.toml to include only specific modules. Do not include 'jmqtui'.
    sed -i '/^\[tool.setuptools.packages.find\]/a include = ["jmbase", "jmbitcoin", "jmclient", "jmdaemon"]' pyproject.toml
  '';

  nativeCheckInputs = [
    pytestCheckHook
  ];

  pytestFlagsArray = [
    "test/jmbase/"
    "test/jmbitcoin/"
    "test/jmdaemon/test_enc_wrapper.py"

    # Other tests require preconfigured bitcoind and miniircd
    # https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/TESTING.md
    # "test/jmclient/"
    # "test/jmdaemon/"
  ];

  pythonImportsCheck = [
    "jmbase"
    "jmbitcoin"
    "jmclient"
    "jmdaemon"
  ];

  meta = with lib; {
    homepage = "https://github.com/Joinmarket-Org/joinmarket-clientserver";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.gpl3;
  };
}
