{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.nix-bitcoin;
in
{
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
        Set permissions for existing secrets in `nix-bitcoin.secretsDir`.
      '';
    };

    generateSecrets = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Automatically generate all required secrets at system startup.
        Note: Make sure to create a backup of the generated secrets.
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
              default = "0440";
            };
          };
        }
      ));
    };

    secretsSetupMethod = mkOption {
      type = types.str;
      default = throw  ''
        Error: No secrets setup method has been defined.
        To fix this, choose one of the following:

         - Use one of the deployment methods in ${toString ./../deployment}

         - Set `nix-bitcoin.generateSecrets = true` to automatically generate secrets

         - Set `nix-bitcoin.secretsSetupMethod = "manual"` if you want to manually setup secrets
      '';
    };
  };

  config = {
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
        ${optionalString cfg.generateSecrets ''
          mkdir -p "${cfg.secretsDir}"
          cd "${cfg.secretsDir}"
          chown root: .
          chmod 0700 .
          ${cfg.pkgs.generate-secrets}
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
            setupSecret ${n} ${v.user} ${v.group} ${v.permissions} }
          '') cfg.secrets)
        }

        # Make all other files accessible to root only
        unprocessedFiles=$(comm -23 <(printf '%s\n' *) <(printf '%s\n' "''${processedFiles[@]}" | sort))
        IFS=$'\n'
        chown root: $unprocessedFiles
        chmod 0440 $unprocessedFiles

        # Now make the secrets dir accessible to other users
        chmod 0751 "$dir"
      '';
    };
  };
}
