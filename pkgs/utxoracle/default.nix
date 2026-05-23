{ lib, stdenv, python3, fetchurl }:

let
  src = fetchurl {
    url = "https://utxo.live/oracle/UTXOracle.py";
    hash = "sha256-m20z+clE3L4oV4R9NAqYSg7p85qR9cwu8XODkmpqAsU=";
  };
in stdenv.mkDerivation {
  pname = "utxoracle";
  # Upstream has no versioned releases. Version is extracted from the source
  # header comment ("Version 9.1 RPC Only"). The hash pins the exact source.
  version = "9.1";

  dontUnpack = true;

  buildInputs = [ python3 ];

  installPhase = ''
    mkdir -p $out/libexec $out/bin $out/share/licenses/utxoracle
    install -Dm644 ${./LICENSE} $out/share/licenses/utxoracle/LICENSE

    # Apply headless patch: make browser open non-fatal for server use
    substitute ${src} $out/libexec/UTXOracle.py \
      --replace-warn \
        '# Write file locally and serve to browser
import webbrowser
with open(filename, "w") as f:
    f.write(html_content)
webbrowser.open('"'"'file://'"'"' + os.path.realpath(filename))' \
        '# Write file locally and optionally open in browser
with open(filename, "w") as f:
    f.write(html_content)
print("Chart saved to " + os.path.realpath(filename))
try:
    import webbrowser
    webbrowser.open('"'"'file://'"'"' + os.path.realpath(filename))
except Exception:
    pass'

    chmod 755 $out/libexec/UTXOracle.py

    cat > $out/bin/utxoracle <<'WRAPPER'
#!/usr/bin/env python3
import runpy, sys, os
script = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "libexec", "UTXOracle.py")
sys.argv[0] = script
runpy.run_path(script, run_name="__main__")
WRAPPER
    chmod +x $out/bin/utxoracle
  '';

  meta = with lib; {
    description = "Bitcoin price oracle using only on-chain UTXO data";
    homepage = "https://utxo.live/oracle/";
    license = {
      fullName = "UTXOracle License 1.0";
      url = "https://utxo.live/oracle/license.php";
      free = false;
    };
    platforms = platforms.all;
    maintainers = [];
  };
}
