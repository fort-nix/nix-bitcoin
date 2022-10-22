{ modulesPath, ... }: {
  imports = [
    # Source:
    # https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/hardened.nix
    (modulesPath + "/profiles/hardened.nix")
  ];

  ## Reset some options set by the hardened profile

  # Needed for sandboxed builds and services
  security.allowUserNamespaces = true;

  # The "scudo" allocator is broken on NixOS >= 20.09
  environment.memoryAllocator.provider = "libc";
}
