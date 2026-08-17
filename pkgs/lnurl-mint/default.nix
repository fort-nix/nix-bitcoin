{ pkgs
, src # the lnurl-mint source (flake input, non-flake)
}:

let
  inherit (pkgs) lib;
  python3Packages = pkgs.python3.pkgs;

  # not in nixpkgs (lnbits' BOLT11 codec) - pinned to the same version and
  # hash as lnurl-mint's uv.lock. Its upstream `requires-python = "<3.13"`
  # cap is conservative (lnurl-mint's whole test suite passes against it on
  # 3.13/3.14), so it's relaxed here rather than failing nixpkgs'
  # interpreter-version check.
  bolt11 = python3Packages.buildPythonPackage rec {
    pname = "bolt11";
    version = "2.2.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-Es2dDT6w8IxQWxg08hYwNpl0wd47nDm5q9SN3Q0aREs=";
    };

    postPatch = ''
      sed -i 's/>=3.10,<3.13/>=3.10/' pyproject.toml
    '';

    build-system = [ python3Packages.hatchling ];

    dependencies = with python3Packages; [
      click
      base58
      coincurve
      bech32
      bitstring
    ];

    # upstream tests want pytest-cov and friends; skipped - lnurl-mint's own
    # suite exercises bolt11 thoroughly (every fake invoice is one)
    doCheck = false;

    meta = {
      description = "A library for encoding and decoding BOLT11 payment requests";
      homepage = "https://github.com/lnbits/bolt11";
      license = lib.licenses.mit;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "lnurl-mint";
  version = "0.1.5";
  pyproject = true;

  inherit src;

  # the fetched source has no .git for hatch-vcs to derive a version from
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python3Packages; [
    fastapi
    uvicorn
    # uvicorn's [standard] extras, spelled out (nixpkgs doesn't propagate
    # extras)
    httptools
    uvloop
    watchfiles
    websockets
    pyyaml
    python-dotenv
    bolt11
    httpx
    pydantic-settings
    qrcode
    bech32
    coincurve
  ];

  # nixpkgs ships a fastapi newer than lnurl-mint's <0.116 pin - relax the
  # metadata bound and let the checkPhase's full test suite adjudicate
  # compatibility (it passes)
  pythonRelaxDeps = [ "fastapi" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # no [project.scripts] upstream - the app is served by uvicorn; wrap it so
  # the module has a single entry point to exec. The wrapper captures the
  # build-time PYTHONPATH (the full dependency closure) plus this package's
  # own site-packages.
  postInstall = ''
    makeWrapper ${lib.getExe python3Packages.uvicorn} $out/bin/lnurl-mint \
      --add-flags "lnurl_mint.server:app" \
      --prefix PYTHONPATH : "$out/${pkgs.python3.sitePackages}:$PYTHONPATH"
  '';

  nativeCheckInputs = [ python3Packages.pytest ];

  # conftest.py isolates itself (throwaway sqlite, dummy dotenv, testserver
  # BASE_URL, FakeNode) - the suite needs no network and no further setup.
  # `python -m pytest` rather than the bare console script: the test modules
  # do `from tests.conftest import ...`, which needs the repo root on
  # sys.path, which only the -m form adds
  checkPhase = ''
    runHook preCheck
    python -m pytest
    runHook postCheck
  '';

  passthru = {
    inherit bolt11;
  };

  meta = {
    description = "Minimal lnurlcash (LUD-25, Lightning bearer assets) mint - LUD-03/LUD-06 only";
    homepage = "https://github.com/dni/lnurl-mint";
    license = lib.licenses.mit;
    mainProgram = "lnurl-mint";
    platforms = lib.platforms.linux;
  };
}
