# Verifying pinned nixpkgs and nixpkgs-unstable commits

Goal
---
All pinned nixpkg commits should be signed by a trusted nixpkgs maintainer with a verified GPG key.

Terms
---
**Trusted:** An individual who has no history of security breaches, is in good standing with the Nix community, has been a NixOS maintainer for at least a year, and is not pseudonymous.

**Nixpkgs maintainer:** An individual who is included in the [nixpkgs maintainers list](https://github.com/NixOS/nixpkgs/blob/master/maintainers/maintainer-list.nix).

**GPG key:** A rsa>2048, ed25519, or 256e GPG/PGP key. 

**Verified:** Verified through _at least_ two of the following (in descending preference)
* **WoT:** GPG key has at least three marginally trusted signatures or one fully trusted signature. 
* **Marginally trusted signatures:** Signatures made by keys trusted by at least one nix-bitcoin developer.
* **Fully trusted signatures:** Signatures made by keys of nix-bitcoin developers.
* **Keybase:** GPG key is listed in a Keybase profile that includes the Nixpkgs maintainer's GitHub. 
* **Website:** GPG key fingerprint is displayed or GPG key is downloadble on a nixpkgs maintainer's personal website.

**nix-bitcoin developer:** jonasnick B1A70E4F8DCD0366, nix-bitcoin D11F9AD5308B3BA

Verified List
---
Nixpkgs maintainer | GPG key | Verifiable through 
--- | --- | ---
[Elis Hirwing](https://github.com/etu) | 0xD57EFA625C9A925F | [WoT](https://pgp.cs.uu.nl/paths/b1a70e4f8dcd0366/to/d57efa625c9a925f.html), [Website](https://elis.nu/)
[Franz Pletz](https://github.com/fpletz) | 0x846FDED7792617B4 | [WoT](https://pgp.cs.uu.nl/paths/b1a70e4f8dcd0366/to/846fded7792617b4.html), [Keybase](https://keybase.io/fpletz)
[Jörg Thalheim](https://github.com/Mic92) | 0xB3F5D81B0C6967C4 | [Keybase](https://keybase.io/mic92), [Website](https://thalheim.io/joerg/)
[Will Dietz](https://github.com/dtzWill) |  0xFD42C7D0D41494C8 | [Keybase](https://keybase.io/dtz) *extensive Keybase*
[Justin Humm](https://github.com/erictapen) | 0x438871E000AA178E | [Keybase](https://keybase.io/erictapen), [Website](https://erictapen.name/impressum.html)
[Vladimír Čunát](https://github.com/vcunat) | 0xE747DF1F9575A3AA | [WoT](https://pgp.cs.uu.nl/paths/b1a70e4f8dcd0366/to/e747df1f9575a3aa.html), [Keybase](https://keybase.io/vcunat)

Not Fully Verified List
---
List of keys that meet only some of the "Verified" terms

Nixpkgs maintainer | GPG key | Verifiable through
--- | --- | ---
[Aaron Janse](https://github.com/ajanse)| 0xBE6C92145BFF4A34 | [Keybase](https://keybase.io/aaronjanse) *no github*, [Website](https://ajanse.me/)
[Artemis Tosini](https://github.com/artemist) *less than a year* | 0x4FDC96F161E7BA8A | [Keybase](https://keybase.io/artemist), [Website](https://artem.ist/keys/)
[Ioannis Koutras](https://github.com/jokogr) | 0x85EAE7D9DF56C5CA | [Keybase](https://keybase.io/joko)
[Michael Weiss](https://github.com/primeos) | 0x130826A6C2A389FD | [Keybase](https://keybase.io/primeos)
[Alyssa Ross](https://github.com/alyssais) | 0x736CCDF9EF51BD97 | [WoT](https://pgp.cs.uu.nl/mk_path.cgi?FROM=b1a70e4f8dcd0366&TO=736CCDF9EF51BD97&PATHS=trust+paths) *not in strong set anymore*, [Website](https://twitter.com/qyliss)
[Sébastien Maret](https://github.com/smaret) | 0x86E30E5A0F5FC59C | [WoT](https://pgp.cs.uu.nl/paths/b1a70e4f8dcd0366/to/86e30e5a0f5fc59c.html)
[Sondre Niles](https://github.com/sondr3) | 0x25676BCBFFAD76B1 | [Keybase](https://keybase.io/sondre)
[Tadeo Kondrak](https://github.com/tadeokondrak) | 0xFBE607FCC49516D3 | [Keybase](https://keybase.io/tdeo)
[Domen Kozar](https://github.com/domenkozar) | 0xC2FFBCAFD2C24246 | [Keybase](https://keybase.io/ielectric) 

Procedure
---
1. Search for most recent signed commit on [nixos-19.03](https://github.com/NixOS/nixpkgs-channels/commits/nixos-19.03) or [nixos-unstable](https://github.com/NixOS/nixpkgs-channels/commits/nixos-unstable)
2. Check that nixpkgs maintainer is in "Verified List"
3. Check that key meets "Verified" terms
4. Verify commit signature
5. Pin commit under nixpkgs or nixpkgs-unstable in `pkgs/nixpkgs-pinned.nix`
