{ config, pkgs, lib, ... }:

with lib;
let
  options.nix-bitcoin = {
    secretsDir = mkOption {
      type = types.path;
      default = "/etc/nix-bitcoin-secrets";
      description = "Directory to store secrets";
    };

    setupSecrets = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Set permissions for existing secrets in {option}`nix-bitcoin.secretsDir`
        before services are started.
      '';
    };

    generateSecrets = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Automatically generate all required secrets before services are started.
        Note: Make sure to create a backup of the generated secrets.
      '';
    };

    generateSecretsCmds = mkOption {
      type = types.attrsOf types.lines;
      default = {};
      description = ''
        Bash expressions for generating secrets.
      '';
    };

    # Currently, this is used only by ../deployment/nixops.nix
    deployment.secretsDir = mkOption {
      type = types.path;
      description = ''
        Directory of local secrets that are transferred to the nix-bitcoin node on deployment
      '';
    };

    secrets = mkOption {
      default = {};
      type = with types; attrsOf (submodule (
        { config, ... }: {
          options = {
            user = mkOption {
              type = str;
              default = "root";
            };
            group = mkOption {
              type = str;
              default = config.user;
            };
            permissions = mkOption {
              type = str;
              default = "440";
            };
          };
        }
      ));
    };

    secretsSetupMethod = mkOption {
      type = with types; nullOr str;
      default = null;
    };

    generateSecretsScript = mkOption {
      internal = true;
      default = let
        rpcauthSrc = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/bitcoin/bitcoin/d6cde007db9d3e6ee93bd98a9bbfdce9bfa9b15b/share/rpcauth/rpcauth.py";
          sha256 = "189mpplam6yzizssrgiyv70c9899ggh8cac76j4n7v0xqzfip07n";
        };
        rpcauth = pkgs.writers.writeBash "rpcauth" ''
          exec ${pkgs.python3}/bin/python ${rpcauthSrc} "$@"
        '';
      # Writes secrets to PWD
      in pkgs.writers.writeBash "generate-secrets" ''
        set -euo pipefail

        export PATH=${lib.makeBinPath (with pkgs; [ coreutils gnugrep ])}

        makePasswordSecret() {
          # Passwords have alphabet {a-z, A-Z, 0-9} and ~119 bits of entropy
          [[ -e $1 ]] || ${pkgs.pwgen}/bin/pwgen -s 20 1 > "$1"
        }
        makeBitcoinRPCPassword() {
          user=$1
          file=bitcoin-rpcpassword-$user
          HMACfile=bitcoin-HMAC-$user
          makePasswordSecret "$file"
          if [[ $file -nt $HMACfile ]]; then
            ${rpcauth} $user $(cat "$file") | grep rpcauth | cut -d ':' -f 2 > "$HMACfile"
          fi
        }
        makeCert() {
          name=$1
          # Add leading comma if not empty
          extraAltNames=''${2:+,}''${2:-}
          if [[ ! -e $name-key ]]; then
            # Create new key and cert
            doMakeCert "-newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout $name-key"
          elif [[ ! -e $name-cert \
                  || $(cat "$name-cert-alt-names" 2>/dev/null) != $extraAltNames ]]; then
            # Create cert from existing key
            doMakeCert "-key $name-key"
          fi;
        }
        doMakeCert() {
           # This fn uses global variables `name` and `extraAltNames`
           keyOpts=$1
           ${pkgs.openssl}/bin/openssl req -x509 \
             -sha256 -days 3650 $keyOpts -out "$name-cert"  \
             -subj "/CN=localhost/O=$name" \
             -addext "subjectAltName=DNS:localhost,IP:127.0.0.1$extraAltNames"
           echo "$extraAltNames" > "$name-cert-alt-names"
        }

        umask u=rw,go=
        ${builtins.concatStringsSep "\n" (builtins.attrValues cfg.generateSecretsCmds)}
      '';
    };
  };

  cfg = config.nix-bitcoin;
in {
  inherit options;

  config = {
    assertions = [
      { assertion = cfg.secretsSetupMethod != null;
        message = ''
          No secrets setup method has been defined.
          To fix this, choose one of the following:

           - Use one of the deployment methods in ${toString ./../deployment}

           - Set `nix-bitcoin.generateSecrets = true` to automatically generate secrets

           - Set `nix-bitcoin.secretsSetupMethod = "manual"` if you want to manually setup secrets
        '';
      }
    ];

    # This target is active when secrets have been setup successfully.
    systemd.targets.nix-bitcoin-secrets = mkIf (cfg.secretsSetupMethod != "manual") {
      # This ensures that the secrets target is always activated when switching
      # configurations.
      # In this way `switch-to-configuration` is guaranteed to show an error
      # when activating the secrets target fails on deployment.
      wantedBy = [ "multi-user.target" ];
    };

    nix-bitcoin.setupSecrets = mkIf cfg.generateSecrets true;

    nix-bitcoin.secretsSetupMethod = mkIf cfg.setupSecrets "setup-secrets";

    # Operation of this service:
    #  - Set owner and permissions for all used secrets
    #  - Make all other secrets accessible to root only
    # For all steps make sure that no secrets are copied to the nix store.
    #
    systemd.services.setup-secrets = mkIf cfg.setupSecrets {
      requiredBy = [ "nix-bitcoin-secrets.target" ];
      before = [ "nix-bitcoin-secrets.target" ];
      serviceConfig = {
         Type = "oneshot";
         RemainAfterExit = true;
      };
      script = ''
        # Use the same sort order for globbing and sorting as in Nix attrsets.
        # Required for `comm` below.
        export LC_COLLATE=C

        ${optionalString cfg.generateSecrets ''
          mkdir -p "${cfg.secretsDir}"
          cd "${cfg.secretsDir}"
          chown root: .
          chmod 0700 .
          ${cfg.generateSecretsScript}
        ''}

        setupSecret() {
           file="$1"
           user="$2"
           group="$3"
           permissions="$4"
           if [[ ! -e $file ]]; then
             echo "Error: Secret file '$file' is missing"
             exit 1
           fi
           chown "$user:$group" "$file"
           chmod "$permissions" "$file"
           processedFiles+=("$file")
        }

        dir="${cfg.secretsDir}"
        if [[ ! -e $dir ]]; then
          echo "Error: Secrets dir '$dir' is missing"
          exit 1
        fi
        chown root: "$dir"
        cd "$dir"

        processedFiles=()
        ${
          concatStrings (mapAttrsToList (n: v: ''
            setupSecret ${n} ${v.user} ${v.group} ${v.permissions}
          '') cfg.secrets)
        }

        # Make all other files accessible to root only
        unprocessedFiles=$(
          comm -23 <(shopt -s nullglob; printf '%s\n' *) <(printf '%s\n' "''${processedFiles[@]}")
        )
        if [[ $unprocessedFiles ]]; then
          IFS=$'\n'
          # shellcheck disable=SC2086
          chown root: $unprocessedFiles
          # shellcheck disable=SC2086
          chmod 0440 $unprocessedFiles
        fi

        # Now make the secrets dir accessible to other users
        chmod 0751 "$dir"
      '';
    };
  };
}
