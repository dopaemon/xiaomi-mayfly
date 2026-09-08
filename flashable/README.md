# Flashable zip

Flashes `boot.img`, `vendor_boot.img` and `dtbo.img` to the active slot from
TWRP. CI drops the images into `images/` and zips this directory up, so a
release asset `UBports-mayfly-<sha>.zip` is a normal TWRP zip.

It deliberately does not touch the rootfs: `ubuntu.img.zst` goes to `system_a`
inside `super`, which first has to have `product_a` and `system_ext_a` removed
and `system_<slot>` grown to 4500M. Halium recovery does that from
`ramdisk-recovery-overlay/prop.halium`; TWRP would need `lptools` and a lot
more care.

So: first install through the UT installer as usual, then use this zip for
every kernel rebuild after that.
