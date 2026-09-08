# Ubuntu Touch for Xiaomi 12S (mayfly)

Halium 16 port, built by `halium-generic-adaptation-build-tools`. The kernel
tree needs a case-sensitive filesystem, so on macOS it builds in Docker (see
[Build](#build)), never on APFS directly.

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

CI is manual: run the `build` workflow from the Actions tab, or

    gh workflow run build --repo dopaemon/xiaomi-mayfly

Images land on a `ci-<run id>` release. Pass `-f flashable=true` to also build
`system.img` from the latest devel OTA. To publish an older run's artifacts
without rebuilding:

    gh workflow run build --repo dopaemon/xiaomi-mayfly -f publish_run_id=<id>

Locally, Docker gives the same ubuntu:22.04 environment CI uses -- needed on
macOS, where APFS is case-insensitive and the kernel tree will not check out:

    docker compose build            # once, to create the image
    docker compose run --rm build

`workdir/` (kernel plus 18 module trees, ~30 GB) and the ccache live in named
volumes; `out/` is bind-mounted, so artifacts appear in the checkout. The first
build is ~40 minutes, later ones far less because ccache is warm. To start over:

    docker compose down -v

On a Linux box with a case-sensitive filesystem, skip Docker entirely:

    ./build.sh

Every release also carries `UBports-mayfly-<sha>.zip`, a TWRP zip that streams
`boot.img`, `vendor_boot.img`, `dtbo.img` and `recovery.img` into the active
slot -- for
reflashing a new kernel without redoing the whole install. It leaves the rootfs
alone; see [flashable/README.md](flashable/README.md).

`ramdisk-overlay/scripts/halium` is the prebuilt initrd's own script with one
change: `androidboot.slot_suffix` is also read from `/proc/bootconfig`. mayfly's
bootloader passes it there rather than on the command line, and without the
suffix the initrd never resolves `systempart=/dev/mapper/system` to the active
slot and the rootfs mount fails. The 12S is happy to keep LineageOS on `_b`, so
`ramdisk-recovery-overlay/prop.halium` frees space on both slots.

`ota.tar` in the release is the OTA set the recovery installs from
(`ubuntu_command` plus the rootfs, Halium GSI, device and version tarballs).
Unpack it into `/cache/recovery` over adb and reboot to recovery: `ubupdater`
finds `ubuntu_command` and runs `system-image-upgrader`, which is what resizes
`system` in super and unpacks the rootfs.

Artifacts: `out/boot.img`, `out/vendor_boot.img`, `out/dtbo.img`,
`out/ubuntu.img.zst`, `out/device_mayfly.tar.xz` and `out/recovery.img` --
Halium recovery goes to mayfly's own 100 MiB `recovery_a`/`recovery_b`, not
into `boot.img`.

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

`prebuilt/mayfly.dtb` and `prebuilt/dtbo.img` are the stock blobs from
LineageOS, not built here. ABL matches the 92 stock dtbo overlays against the
base DTBs in `vendor_boot` by id/rev, and this tree only builds 3 of the 14
bases plus 1 of the 92 overlays -- flashing either of ours leaves the rest with
nothing to attach to and the bootloader drops to fastboot. See the comment in
`deviceinfo` for how to go back to building them.

Flashing by hand needs verification off, or the bootloader rejects our images:

    fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img

## Still missing

- `overlay/` covers gbinder.conf, deviceinfo yaml, QCOM udev rules, libinput
  quirks and the lxc-android-config overrides. RIL (`ofono/binder.d`), MTP
  (usb-moded/umtprd) and USB tethering are written after first boot.
- `vendor-ramdisk-overlay/lib/modules/modules.load` is the kernel's own
  `modules.list.msm.waipio` (100 modules). Stock loads 12 more Xiaomi-specific
  ones (`bootinfo`, `mi_memory`, `mi_power`, `metis`, `swinfo`, ...); add them
  if something is missing at first stage.

## License

MIT, see [LICENSE](LICENSE). The build tools and the kernel keep their own
licenses.
