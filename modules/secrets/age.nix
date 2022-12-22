{ config, pkgs, lib, ... }:

with lib;
let
  options.nix-bitcoin.age = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable age-encrypted secrets.

        This requires that the [agenix](https://github.com/ryantm/agenix)
        module is included in your config.
      '';
    };

    secretsSourceDir = mkOption {
      type = types.path;
      example = literalExpression "./secrets";
      description = mdDoc ''
        The directory where age-encrypted secrets are stored.
      '';
    };

    publicKeys = mkOption {
      type = with types; listOf str;
      example = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0idNvgGiucWgup/mP78zyC23uFjYq0evcWdjGQUaBH" ];
      description = mdDoc ''
        Public keys for encrypting the secrets.

        A sensible default is to set this to the ed25519 public SSH host key of your node.
        You can query host keys with command {command}`ssh-keyscan <node address>`.

        When not using a SSH host key, make sure to set the corresponding agenix
        option {option}`age.identityPaths`.
      '';
    };

    generateSecretsScript = mkOption {
      readOnly = true;

      description = mdDoc secretsScriptLib.scriptHelp;

      default = pkgs.writers.writeBashBin "generate-secrets" ''
        ${secretsScriptLib.gotoDestDir}

        tmpSecretsDir=$(mktemp -d)
        trap 'rm -rf $tmpSecretsDir' EXIT

        # 1. Generate secrets to a tmp dir
        pushd "$tmpSecretsDir" >/dev/null
        ${config.nix-bitcoin.generateSecretsScriptImpl}
        popd >/dev/null

        # 2. Age-encrypt each secret to $PWD/$name.age
        encrypt() {
          ${getExe pkgs.rage} "$tmpSecretsDir/$1" -o "$1.age" ${
            concatMapStringsSep " " (pubkey:
              "--recipient ${escapeShellArg pubkey}"
            ) cfg.publicKeys
          }
        }
        ${
          concatMapStrings (name: ''
            encrypt "${name}"
          '') (builtins.attrNames config.nix-bitcoin.secrets)
        }
      '';
    };
  };

  cfg = config.nix-bitcoin.age;
  inherit (config.nix-bitcoin) secretsScriptLib;
in {
  inherit options;

  config = {
    nix-bitcoin.secretsSetupMethod = "age";

    nix-bitcoin.secretsDir = config.age.secretsDir;

    # The `nix-bitcoin-secrets` target has no dependencies,
    # because agenix runs via the activation script, before systemd.
    systemd.targets.nix-bitcoin-secrets = {};

    age.secrets = mapAttrs (name: value: {
      owner = value.user;
      group = value.group;
      mode = value.permissions;
      file = (cfg.secretsSourceDir + "/${name}.age");
    }) config.nix-bitcoin.secrets;
  };
}
