# You can run this test via `run-tests.sh -s wireguard-lndconnect`

makeTestVM: pkgs:
with pkgs.lib;

makeTestVM {
  name = "wireguard-lndconnect";

  nodes = {
    server = {
      imports = [
        ../modules/modules.nix
        ../modules/presets/wireguard.nix
      ];

      nixpkgs.pkgs = pkgs;

      nix-bitcoin.generateSecrets = true;
      nix-bitcoin.operator.enable = true;

      services.clightning = {
        enable = true;
        plugins.clnrest = {
          enable = true;
          lnconnect.enable = true;
        };
      };

      services.clightning-rest = {
        enable = true;
        lndconnect.enable = true;
      };
      # TODO-EXTERNAL:
      # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s.
      services.clightning.extraConfig = ''
        disable-dns
      '';

      services.lnd = {
        enable = true;
        lndconnect.enable = true;
        port = 9736;
      };
    };

    client = {
      nixpkgs.pkgs = pkgs;

      environment.systemPackages = with pkgs; [
        wireguard-tools
      ];
    };
  };

  testScript =  ''
    import base64
    import urllib.parse as Url
    from types import SimpleNamespace

    def parse_lndconnect_url(url):
        u = Url.urlparse(url)
        data = {'host': u.hostname, 'port': u.port}
        queries = Url.parse_qs(u.query)
        if url.startswith("clnrest"):
            data['rune'] = queries['rune'][0]
        else:
            macaroon = queries['macaroon'][0]
            if url.startswith("c-lightning-rest"):
              data['macaroon_hex'] = macaroon
            else:
              # lnd
              data['macaroon_hex'] = base64.urlsafe_b64decode(macaroon + '===').hex().upper()

        return SimpleNamespace(**data)

    client.start()
    server.connect()

    if not "is_interactive" in vars():

      with subtest("connect client to server via WireGuard"):
          server.wait_for_unit("wireguard-wg-nb-peer-peer0.service")

          # Get WireGuard config from server and save it to `/tmp/wireguard.conf` on the client
          wg_config = server.succeed("runuser -u operator -- nix-bitcoin-wg-connect server --text")
          # Encode to base64
          b64 = base64.b64encode(wg_config.encode('utf-8')).decode()
          client.succeed(f"install -m 400 <(echo -n {b64} | base64 -d) /tmp/wireguard.conf")

          # Connect to server via WireGuard
          client.succeed("wg-quick up /tmp/wireguard.conf")

          # Ping server from client
          print(client.succeed("ping -c 1 -W 0.5 10.10.0.1"))

      with subtest("lndconnect-wg"):
          server.wait_for_unit("lnd.service")
          lndconnect_url = server.succeed("runuser -u operator -- lndconnect-wg --url")
          api = parse_lndconnect_url(lndconnect_url)
          # Make lnd REST API call
          client.succeed(
              f"curl -fsS --max-time 3 --insecure --header 'Grpc-Metadata-macaroon: {api.macaroon_hex}' "
              f"-X GET https://{api.host}:{api.port}/v1/getinfo"
          )

      with subtest("lnconnect-clnrest-wg"):
          server.wait_for_unit("clightning.service")
          lndconnect_url = server.succeed("runuser -u operator -- lnconnect-clnrest-wg --url")
          api = parse_lndconnect_url(lndconnect_url)
          # Make clnrest API call
          client.succeed(
              f"curl -fsS --max-time 3 --insecure --header 'rune: {api.rune}' "
              f"-X POST https://{api.host}:{api.port}/v1/getinfo"
          )

      with subtest("lndconnect-clightning-wg"):
          server.wait_for_unit("clightning-rest.service")
          lndconnect_url = server.succeed("runuser -u operator -- lndconnect-clightning-wg --url")
          api = parse_lndconnect_url(lndconnect_url)
          # Make clightning-rest API call
          client.succeed(
              f"curl -fsS --max-time 3 --insecure --header 'macaroon: {api.macaroon_hex}' "
              f"--header 'encodingtype: hex' -X GET https://{api.host}:{api.port}/v1/getinfo"
          )
  '';
}
