{ lib }:
{
  # An address type that checks that there's no port
  ipv4Address = lib.types.addCheck lib.types.str (s: builtins.length (builtins.split ":" s) == 1);
}
