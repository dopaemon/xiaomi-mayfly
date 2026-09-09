# Flashable zip

Flashes `boot.img`, `vendor_boot.img`, `dtbo.img` and `vendor_dlkm.img` to the
active slot from TWRP. CI drops the images into `images/` and zips this
directory up, so a release asset `UBports-mayfly-<sha>.zip` is a normal TWRP
zip.

`recovery.img` is **not** flashed. Halium recovery and TWRP share the one
100 MiB recovery partition, and this zip is installed from TWRP: flashing it
would destroy the rescue path you are standing on. It ships as a separate
release asset -- fastboot it by hand when the UT installer needs it, then put
TWRP back.

`dtbo.img` is the stock blob from `prebuilt/`, never a built one: ABL matches
the overlays against the base DTBs in vendor_boot and drops to fastboot if they
disagree.

It deliberately does not touch the rootfs: `ubuntu.img.zst` goes to `system_a`
inside `super`, which first has to have `product_a` and `system_ext_a` removed
and `system_<slot>` grown to 4500M. Halium recovery does that from
`ramdisk-recovery-overlay/prop.halium`; TWRP would need `lptools` and a lot
more care.

So: first install through the UT installer as usual, then use this zip for
every kernel rebuild after that.
