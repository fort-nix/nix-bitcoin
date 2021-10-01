Hardware requirements
---
* RAM: 2GB. ECC memory is better. Additionally, it's recommended to use DDR4 memory with
  targeted row refresh (TRR) enabled (https://rambleed.com/).
* Disk space: 500 GB (400GB for Bitcoin blockchain + some room) for an unpruned
  instance of Bitcoin Core.
  * This can be significantly lowered by enabling pruning.
    Note: Pruning is not supported by `electrs`.

Tested low-end hardware includes:
- [Raspberry Pi 4](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/)
- [PC Engines apu2c4](https://pcengines.ch/apu2c4.htm)
- [Gigabyte GB-BACE-3150](https://www.gigabyte.com/Mini-PcBarebone/GB-BACE-3150-rev-10)
- [Gigabyte GB-BACE-3160](https://www.gigabyte.com/de/Mini-PcBarebone/GB-BACE-3160-rev-10#ov)

Some hardware (including Intel NUCs) may not be compatible with the [hardened kernel preset](../modules/presets/hardened.nix)
(See https://github.com/fort-nix/nix-bitcoin/issues/39#issuecomment-517366093
for a workaround).
