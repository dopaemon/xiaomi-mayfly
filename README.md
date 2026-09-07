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

## Still missing

- `overlay/` — gbinder.conf, ofono binder config, udev rules, deviceinfo yaml,
  usb-moded config. Written after first boot, per subsystem.
- `vendor-ramdisk-overlay/lib/modules/modules.load` — first-stage module list,
  derived from `modules.list.msm.waipio` in the kernel tree.
