Hardware requirements
---
* Disk space: 500 GB (400GB for Bitcoin blockchain + some room)
  * Bitcoin Core pruning is not supported at the moment because it's not supported by c-lightning. It's possible to use pruning but you need to know what you're doing.
* RAM: 2GB of memory. ECC memory is better. Additionally, it's recommended to use DDR4 memory with targeted row refresh (TRR) enabled (https://rambleed.com/).

Tested hardware includes [pcengine's apu2c4](https://pcengines.ch/apu2c4.htm), [GB-BACE-3150](https://www.gigabyte.com/Mini-PcBarebone/GB-BACE-3150-rev-10), [GB-BACE-3160](https://www.gigabyte.com/de/Mini-PcBarebone/GB-BACE-3160-rev-10#ov).
Some hardware (including Intel NUCs) may not be compatible with the hardened kernel turned on by default (see https://github.com/fort-nix/nix-bitcoin/issues/39#issuecomment-517366093 for a workaround).
