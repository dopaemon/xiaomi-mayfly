#!/bin/sh
# mayfly debug access. Independent of Lomiri and of lightdm so a wedged shell
# never takes it out, which is the whole point: without this the only way to
# read a log was to flash the LineageOS boot chain, boot TWRP and mount system_b
# by hand for every single attempt.
#
# Config and the authorized key ship read-only in /etc/mayfly; only the host key
# and the log dumps need a writable place, and that is /userdata.
set -x
exec >>/userdata/mayfly-debug.log 2>&1

D=/userdata
C=/etc/mayfly
STATIC=192.168.1.222/24
# SHA-512 crypt of "phablet". Written out by openssl passwd -6 with a fixed salt
# so this file stays reproducible.
ROOT_HASH='$6$mayflydebug$C8KmHrhxdfAUAXEI7N/v5bxQAtyJ5pTjSV3s7FUsi5D9ucY7MDOqoLR49XYraTgmBlNTXSw/CdRqZOJqJSqM/0'

[ -f $D/mayfly_hostkey ] || ssh-keygen -t ed25519 -N '' -f $D/mayfly_hostkey
chmod 600 $D/mayfly_hostkey
mkdir -p /run/sshd

# root has no usable password in the shipped rootfs, so give it the documented
# default. The rootfs is read only and must stay that way, so patch a copy and
# bind it over /etc/shadow -- the same trick mount-android-partitions uses for
# /etc/group and the Android .rc files. Nothing is written to disk.
#   password: phablet
if ! [ -f /run/mayfly-shadow ]; then
    awk -F: -v OFS=: -v h="$ROOT_HASH" '$1 == "root" { $2 = h } 1' \
        /etc/shadow >/run/mayfly-shadow
    chmod 600 /run/mayfly-shadow
    mount --bind /run/mayfly-shadow /etc/shadow
fi

/usr/sbin/sshd -D -f $C/sshd_config &

while :; do
    # Only alias onto the interface that already reached the LAN, otherwise we
    # would answer for an address on a network the phone is not on. The USB
    # side is handled by mayfly-usbnet.service, which owns usb0.
    IF=$(ip -o -4 addr show scope global | awk '$4 ~ /^192\.168\.1\./ {print $2; exit}')
    [ -n "$IF" ] && ip addr replace $STATIC dev "$IF"

    # A hard hang rolls back uncommitted ext4 data, hence the sync each round.
    journalctl -b --no-pager > $D/mayfly-journal.log 2>&1
    dmesg > $D/mayfly-kmsg.log 2>&1
    ip -4 addr > $D/mayfly-net.log 2>&1
    # Keeps mayfly-clock.service's stamp current across an unclean shutdown.
    touch $D/mayfly-clock-stamp
    # When the UI stalls, lomiri keeps handling sensor and battery events, so
    # there is no log line to find: the state is only visible as what each
    # thread is blocked in. This is what identified the DBus stall.
    {
        for p in $(pgrep -f 'lomiri|hwcomposer|android.hardware.graphics'); do
            echo "== $p $(cat /proc/$p/comm 2>/dev/null)"
            for t in /proc/$p/task/*; do
                echo "  $(cat $t/comm 2>/dev/null) state=$(awk '/^State:/{print $2}' $t/status 2>/dev/null) wchan=$(cat $t/wchan 2>/dev/null)"
            done
        done
    } > $D/mayfly-stacks.log 2>&1
    sync
    sleep 20
done
