#!/bin/sh
# The RTC comes up reading 1970 whenever the previous boot did not write it
# back, and this kernel has neither CONFIG_RTC_SYSTOHC nor CONFIG_RTC_HCTOSYS,
# so nothing does. systemd 255 cannot help either: reading /usr/lib/clock-epoch
# only landed in v256, and this build has no reference to it at all -- the
# compiled-in TIME_EPOCH is all it has, and it clearly is not being applied
# here. Everything dated is then wrong until timesyncd reaches a network: TLS
# certificates, the journal, and shadow's lastchange, which used to hang PAM.
#
# So keep our own stamp on /userdata and never let the clock start before it.
set -eu
STAMP=/userdata/mayfly-clock-stamp

[ -e "$STAMP" ] || touch "$STAMP"

now=$(date +%s)
last=$(stat -c %Y "$STAMP")

if [ "$now" -lt "$last" ]; then
    date -s "@$last" >/dev/null
    echo "advanced clock to $(date)" >&2
fi
