{
  lib,
  rustPlatform,
  clightning,
  unzip,
  protobuf,
}:
rustPlatform.buildRustPackage rec {
  pname = "clnrest";
  version = "0.2.0";

  inherit (clightning) src;

  cargoHash = "sha256-0rpr941QkDeNLQ6Se9+DbbVBCmGyU721a27XNzylpPw=";

  depsExtraArgs = {
    nativeBuildInputs = [ unzip ];
    # Don't run `configure` of the main project build
    dontConfigure = true;
  };

  nativeBuildInputs = [
    # For unpacking the src
    unzip
  ];

  cargoBuildFlags = [ "--package clnrest" ];

  nativeCheckInputs = [
    # Required by lightning/cln-grpc/build.rs
    protobuf
  ];

  # `core::lsps2::htlc::tests::polls_until_channel_ready` (in the `cln-lsps`
  # workspace member) is timing-dependent: it spawns a polling task, sleeps a
  # real 10 ms, then asserts the loop ran more than once. Under the parallel
  # test load in CI the spawned task gets starved and the assertion fails.
  # Skip this single upstream test; the remaining workspace tests still run.
  checkFlags = [ "--skip=polls_until_channel_ready" ];

  meta = with lib; {
    description = "REST plugin for clightning";
    homepage = "https://github.com/ElementsProject/lightning/tree/master/plugins/rest-plugin";
    license = licenses.mit;
    maintainers = with maintainers; [
      erikarvstedt
    ];
    mainProgram = "clnrest";
  };
}
