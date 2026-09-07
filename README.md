# Ubuntu Touch for Xiaomi 12S Pro (mayfly)

Halium 16 port. Built by `halium-generic-adaptation-build-tools`; nothing here
is compiled locally on macOS (the kernel tree needs a case-sensitive
filesystem).

## Sources

| Repo | Branch |
| --- | --- |
| [android_kernel_xiaomi_common](https://github.com/dopaemon/android_kernel_xiaomi_common) | `halium-16.0` |
| [android_kernel_xiaomi_sm8450-devicetrees](https://github.com/LineageOS/android_kernel_xiaomi_sm8450-devicetrees) | `lineage-23.0` |
| [android_kernel_xiaomi_sm8450-modules](https://github.com/LineageOS/android_kernel_xiaomi_sm8450-modules) | `lineage-23.0` |

Both extra repos are cloned next to the kernel as `sm8450-devicetrees` and
`sm8450-modules`, matching the in-tree symlink
`arch/arm64/boot/dts/vendor -> ../../../../../sm8450-devicetrees`.

## Build

Push to GitLab and let CI run it, or on a Linux box with a case-sensitive FS:

    ./build.sh

Artifacts: `out/boot.img`, `out/vendor_boot.img`, `out/dtbo.img`,
`out/recovery.img`, `out/ubuntu.img`.

## Verified against stock

Values below were read out of `mayfly_images_OS2.0.209.0.VLTCNXM` with
`unpack_bootimg.py`, not guessed:

- boot header v4, pagesize 0x1000, kernel 0x8000 / ramdisk 0x1000000 /
  tags 0x100 / dtb 0x1f00000
- boot.img header says OS 12.0.0, patch level 2025-02
- stock boot.img cmdline is empty; `video=`/`disable_dma32=` live in
  vendor_boot, `androidboot.*` in bootconfig
- both ramdisks are lz4
- the three base DTBs we build (`cape` = Cape SoC, `cape-v2` = Cape LTE Only,
  `capep` = CapeP) match stock entries 0-2 of its 14-DTB blob

## Still missing

- `overlay/` — gbinder.conf, ofono binder config, udev rules, deviceinfo yaml,
  usb-moded config. Written after first boot, per subsystem.
- `vendor-ramdisk-overlay/lib/modules/modules.load` is the kernel's own
  `modules.list.msm.waipio` (100 modules). Stock loads 12 more Xiaomi-specific
  ones (`bootinfo`, `mi_memory`, `mi_power`, `metis`, `swinfo`, ...); add them
  if something is missing at first stage.
