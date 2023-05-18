# This file allows you to build your krops configuration locally
{
  imports = [
    ../configuration.nix
    <nix-bitcoin/modules/deployment/krops.nix>
  ];
}
