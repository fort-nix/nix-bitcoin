{ lib, stdenv, python, makePythonHook, setuptools-rust, rust }:
makePythonHook {
  name = "setuptools-rust-setup-hook";
  propagatedBuildInputs = [ setuptools-rust ];
  substitutions = {
    pyLibDir = "${python}/lib/${python.libPrefix}";
    cargoBuildTarget = rust.toRustTargetSpec stdenv.hostPlatform;
    cargoLinkerVar = lib.toUpper (
      builtins.replaceStrings ["-"] ["_"] (
        rust.toRustTarget stdenv.hostPlatform));
    targetLinker = "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc";
  };
} ./setuptools-rust-hook.sh
