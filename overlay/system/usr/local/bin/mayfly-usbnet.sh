#!/bin/sh
# mayfly debug: bring up a USB network gadget so the phone can be reached over
# the one cable it has. This used to run an adb gadget, but adbd never wrote its
# descriptors to ep0, so ffs_alloc() returned -ENODEV and every UDC bind failed
# ("failed to start mayfly: -19"). CDC-ECM is built into the GKI kernel and
# needs no userspace daemon at all, so the bind cannot fail the same way.
# usb-moded is masked while this is in place -- it would fight over the gadget.
set -x
exec >>/userdata/mayfly-usbnet.log 2>&1

G=/sys/kernel/config/usb_gadget/mayfly
DEV_IP=10.15.19.82/24
DEV_MAC=02:1a:11:00:00:01

mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config

mkdir -p "$G/functions/ecm.usb0" "$G/configs/c.1/strings/0x409" "$G/strings/0x409"
echo 0x18d1 > "$G/idVendor"
echo 0x4ee3 > "$G/idProduct"
echo mayfly          > "$G/strings/0x409/serialnumber"
echo Xiaomi          > "$G/strings/0x409/manufacturer"
echo "Mayfly Halium" > "$G/strings/0x409/product"
echo ecm             > "$G/configs/c.1/strings/0x409/configuration"
# Fixed MACs, otherwise macOS sees a new interface on every boot and the host
# side address has to be reassigned by hand each time.
echo 02:1a:11:00:00:01 > "$G/functions/ecm.usb0/dev_addr"
echo 02:1a:11:00:00:02 > "$G/functions/ecm.usb0/host_addr"
ln -sfn "$G/functions/ecm.usb0" "$G/configs/c.1/ecm.usb0"

# Android's init.qcom.usb.rc and vendor.usbgadget-hal keep reclaiming the UDC,
# so this does not give up after a fixed number of tries: it keeps taking the
# controller back for as long as the service runs.
while :; do
    if [ -n "$(cat "$G/UDC" 2>/dev/null)" ]; then
        # Never assume "usb0": once udevd is up it renames the ECM netdev by
        # its MAC (enx021a11000001), and a faster boot is enough to change
        # which side of that race we are on. configfs knows the real name.
        IF=$(cat "$G/functions/ecm.usb0/ifname" 2>/dev/null)
        if [ -n "$IF" ]; then
            REAL=$(ip -o link show | awk -v m="$DEV_MAC" '$0 ~ m { sub(":$", "", $2); print $2; exit }')
            [ -n "$REAL" ] && IF=$REAL
            ip addr replace $DEV_IP dev "$IF" 2>/dev/null
            ip link set "$IF" up 2>/dev/null
        fi
        sleep 10
        continue
    fi
    for g in /sys/kernel/config/usb_gadget/*/; do
        [ "$g" = "$G/" ] && continue
        echo "" > "$g/UDC" 2>/dev/null
    done
    printf %s a600000.dwc3 > "$G/UDC" 2>/dev/null && echo "mayfly-usbnet: bound"
    sleep 2
done
