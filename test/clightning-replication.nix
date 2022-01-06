# You can run this test via `run-tests.sh -s clightningReplication`

let
  nixpkgs = (import ../pkgs/nixpkgs-pinned.nix).nixpkgs;
in
import "${nixpkgs}/nixos/tests/make-test-python.nix" ({ pkgs, ... }:
with pkgs.lib;
let
  keyDir = "${nixpkgs}/nixos/tests/initrd-network-ssh";
  keys = {
    server = "${keyDir}/ssh_host_ed25519_key";
    client = "${keyDir}/id_ed25519";
    serverPub = readFile "${keys.server}.pub";
    clientPub = readFile "${keys.client}.pub";
  };

  clientBaseConfig = {
    imports = [ ../modules/modules.nix ];

    nix-bitcoin.generateSecrets = true;

    services.clightning = {
      enable = true;
      replication.enable = true;

      # TODO-EXTERNAL:
      # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s.
      extraConfig = "disable-dns";
    };
  };
in
{
  name = "clightning-replication";

  nodes = let nodes = {
    replicationLocal = {
      imports = [ clientBaseConfig ];
      services.clightning.replication.local.directory = "/var/backup/clightning";
    };

    replicationLocalEncrypted = {
      imports = [ nodes.replicationLocal ];
      services.clightning.replication.encrypt = true;
    };

    replicationRemote = {
      imports = [ clientBaseConfig ];
      nix-bitcoin.generateSecretsCmds.clightning-replication-ssh-key = mkForce ''
        install -m 600 ${keys.client} clightning-replication-ssh-key
      '';
      programs.ssh.knownHosts."server".publicKey = keys.serverPub;
      services.clightning.replication.sshfs.destination = "nb-replication@server:writable";
    };

    replicationRemoteEncrypted = {
      imports = [ nodes.replicationRemote ];
      services.clightning.replication.encrypt = true;
    };

    server = { ... }: {
      environment.etc."ssh-host-key" = {
        source = keys.server;
        mode = "400";
      };

      services.openssh = {
        enable = true;
        extraConfig = ''
          Match user nb-replication
            ChrootDirectory /var/backup/nb-replication
            AllowTcpForwarding no
            AllowAgentForwarding no
            ForceCommand internal-sftp
            PasswordAuthentication no
            X11Forwarding no
        '';
        hostKeys = mkForce [
          {
            path = "/etc/ssh-host-key";
            type = "ed25519";
          }
        ];
      };

      users.users.nb-replication = {
        isSystemUser = true;
        group = "nb-replication";
        shell = "${pkgs.coreutils}/bin/false";
        openssh.authorizedKeys.keys = [ keys.clientPub ];
      };
      users.groups.nb-replication = {};

      systemd.tmpfiles.rules = [
        # Because this directory is chrooted by sshd, it must only be writable by user/group root
        "d /var/backup/nb-replication 0755 root root - -"
        "d /var/backup/nb-replication/writable 0700 nb-replication - - -"
      ];
    };
  }; in nodes;

  testScript =  { nodes, ... }: let
    systems = builtins.concatStringsSep ", "
      (mapAttrsToList (name: node: ''"${name}": "${node.config.system.build.toplevel}"'') nodes);
  in ''
    systems = { ${systems} }

    def switch_to_system(system):
        cmd = f"{systems[system]}/bin/switch-to-configuration test >&2"
        client.succeed(cmd)

    client = replicationLocal

    if not "is_interactive" in vars():
      client.start()
      server.start()

      with subtest("local replication"):
          client.wait_for_unit("clightning.service")
          client.succeed("runuser -u clightning -- ls /var/backup/clightning/lightningd.sqlite3")
          # No other user should be able to read the backup directory
          client.fail("runuser -u bitcoin -- ls /var/backup/clightning")

      # If `switch_to_system` succeeds then all services, including clightning,
      # have started successfully
      switch_to_system("replicationLocalEncrypted")
      with subtest("local replication encrypted"):
          replica_db = "/var/cache/clightning-replication/plaintext/lightningd.sqlite3"
          client.succeed(f"runuser -u clightning -- ls {replica_db}")
          # No other user should be able to read the unencrypted files
          client.fail(f"runuser -u bitcoin -- ls {replica_db}")
          # A gocryptfs has been created
          client.succeed("ls /var/backup/clightning/lightningd-db/gocryptfs.conf")

      server.wait_for_unit("sshd.service")
      switch_to_system("replicationRemote")
      with subtest("remote replication"):
          replica_db = "/var/cache/clightning-replication/sshfs/lightningd.sqlite3"
          client.succeed(f"runuser -u clightning -- ls {replica_db}")
          # No other user should be able to read the unencrypted files
          client.fail(f"runuser -u bitcoin -- ls {replica_db}")
          # A clighting db exists on the server
          server.succeed("ls /var/backup/nb-replication/writable/lightningd.sqlite3")

      switch_to_system("replicationRemoteEncrypted")
      with subtest("remote replication encrypted"):
          replica_db = "/var/cache/clightning-replication/plaintext/lightningd.sqlite3"
          client.succeed(f"runuser -u clightning -- ls {replica_db}")
          # No other user should be able to read the unencrypted files
          client.fail(f"runuser -u bitcoin -- ls {replica_db}")
          # A gocryptfs has been created on the server
          server.succeed("ls /var/backup/nb-replication/writable/lightningd-db/gocryptfs.conf")
  '';
})
