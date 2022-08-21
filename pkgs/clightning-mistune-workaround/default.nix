{ clightning, python3 }:

clightning.override {
  python3 = python3.override {
    packageOverrides = self: super: {
      mistune = self.callPackage ./mistune.nix {
        version = "0.8.4";
        sha256 = "59a3429db53c50b5c6bcc8a07f8848cb00d7dc8bdb431a4ab41920d201d4756e";
      };
    };
  };
}
