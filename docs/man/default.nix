{ pkgs ? import <nixpkgs> {} }:

let

  lib = pkgs.lib;

  nmdSrc = pkgs.fetchFromGitLab {
    name = "nmd";
    owner = "rycee";
    repo = "nmd";
    rev = "2398aa79ab12aa7aba14bc3b08a6efd38ebabdc5";
    sha256 = "0yxb48afvccn8vvpkykzcr4q1rgv8jsijqncia7a5ffzshcrwrnh";
  };

  nmd = import nmdSrc { inherit pkgs; };

  # Make sure the used package is scrubbed to avoid actually instantiating
  # derivations.
  #
  # Also disable checking since we'll be referring to undefined options.
  setupModule = {
    imports = [{
      _module.args = {
        pkgs = lib.mkForce (nmd.scrubDerivations "pkgs" pkgs);
      };
      _module.check = false;
    }];
  };

  nbModulesDocs = nmd.buildModulesDocs {
    modules = let
      nixosModule = module: pkgs.path + "/nixos/modules" + module;
    in [
      ../../modules/bitcoind.nix
      (nixosModule "/misc/assertions.nix")
      setupModule
    ];
    moduleRootPaths = [ ../modules ];
    mkModuleUrl = path:
      "https://github.com/fort-nix/nix-bitcoin/blob/master/${path}#blob-path";
    channelName = "nix-bitcoin";
    docBook.id = "nb-options";
  };

  docs = nmd.buildDocBookDocs {
    pathName = "nix-bitcoin";
    modulesDocs = [ nbModulesDocs ];
    documentsDirectory = ./.;
    chunkToc = ''
      <toc>
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-nix-bitcoin-manual"><?dbhtml filename="index.html"?>
          <d:tocentry linkend="ch-nb-options"><?dbhtml filename="nb-options.html"?></d:tocentry>
        </d:tocentry>
      </toc>
    '';
  };

in {
  options = {
    json = pkgs.symlinkJoin {
      name = "nix-bitcoin-options-json";
      paths = [
        (nbModulesDocs.json.override {
          path = "share/doc/nix-bitcoin/nb-options.json";
        })
      ];
    };
  };

  manPages = docs.manPages;

  manual = { inherit (docs) html htmlOpenTool; };
}
