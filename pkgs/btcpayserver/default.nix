{
stdenv,
fetchFromGitHub,
fetchurl,
dotnetPackages,
dotnetCorePackages,
lib,
writeScript,
bash
}:

let
  deps = import ./deps.nix {inherit fetchurl;};
  dotnet-sdk = dotnetCorePackages.sdk_3_1;
  bin-script = writeScript "btcpayserver" ''
    #!${bash}/bin/bash
    ${dotnetCorePackages.sdk_3_1}/bin/dotnet run --no-launch-profile --no-build -c Release -p "@@REPLACE@@/BTCPayServer/BTCPayServer.csproj" -- $@
  '';
in

stdenv.mkDerivation rec {
  name = "btcpayserver";
  version = "1.0.5.4";

  src = fetchFromGitHub {
    owner = "btcpayserver";
    repo = "btcpayserver";
    rev = "v${version}";
    sha256 = "1h4567di6sfr6z734b7a7qh0hv5ywq14hlbimxcfxn9hri2g3zbv";
  };
  buildInputs = [dotnet-sdk dotnetPackages.Nuget];

  buildPhase = ''
    mkdir home
    export HOME=$PWD/home

    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_SKIP_FIRST_EXPERIENCE=1

    for package in ${toString deps}; do
      nuget add $package -Source nixos
    done

    dotnet restore --source nixos BTCPayServer.Client/BTCPayServer.Client.csproj
    dotnet build --no-restore -c Release BTCPayServer.Client/BTCPayServer.Client.csproj

    dotnet restore --source nixos BTCPayServer.Data/BTCPayServer.Data.csproj
    dotnet build --no-restore -c Release BTCPayServer.Data/BTCPayServer.Data.csproj

    dotnet restore --source nixos BTCPayServer.Common/BTCPayServer.Common.csproj
    dotnet build --no-restore -c Release BTCPayServer.Common/BTCPayServer.Common.csproj

    dotnet restore --source nixos BTCPayServer.Rating/BTCPayServer.Rating.csproj
    dotnet build --no-restore -c Release BTCPayServer.Rating/BTCPayServer.Rating.csproj

    dotnet restore --source nixos BTCPayServer/BTCPayServer.csproj
    dotnet build --no-restore -c Release BTCPayServer/BTCPayServer.csproj
  '';

  installPhase = ''
      mkdir -p $out/bin/
      cp -r ./* $out
      <${bin-script} sed "s,@@REPLACE@@,$out," > $out/bin/${name}
      chmod +x $out/bin/${name}
  '';

  dontStrip = true;

  meta = with lib; {
    description = "BTCPay Server is a self-hosted, open-source cryptocurrency payment processor. It's secure, private, censorship-resistant and free";
    longDescription =
    ''
      A free and open-source cryptocurrency payment processor which allows you to receive payments in Bitcoin and altcoins directly, with no fees, transaction cost or a middleman.
      BTCPay is a non-custodial invoicing system which eliminates the involvement of a third-party. Payments with BTCPay go directly to your wallet, which increases the privacy and security. Your private keys are never uploaded to the server. There is no address re-use, since each invoice generates a new address deriving from your xpubkey.
      The software is built in C# and conforms to the invoice API of BitPay. It allows for your website to be easily migrated from BitPay and configured as a self-hosted payment processor.
      You can run BTCPay as a self-hosted solution on your own server, or use a third-party host.
      The self-hosted solution allows you not only to attach an unlimited number of stores and use the Lightning Network but also become the payment processor for others. Thanks to the apps built on top of it, you can use BTCPay to receive donations, start a crowdfunding campaign or have an in-store Point of Sale
    '';
    homepage = "https://btcpayserver.org";
    maintainers = with maintainers; [ kcalvinalvin ];
    license = stdenv.lib.licenses.mit;
    platforms = stdenv.lib.platforms.linux;
  };
}
