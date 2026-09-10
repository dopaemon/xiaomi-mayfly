#!/bin/sh
# Suspend the device a while after the screen goes off, on battery only.
#
# Nothing else does. repowerd's user_inactivity_normal_suspend_timeout is the
# hardcoded infinite_timeout in DefaultStateMachineOptions, libsuspend.so is
# gone in Android 12+ so it falls back to LogindSystemPowerControl and never
# calls suspend() by itself, CONFIG_PM_AUTOSLEEP is not set, and
# android.system.suspend-service only waits on binder because Halium has no
# system_server to call it. So the screen turns off and the SoC stays awake at
# ~200mA. repowerd still owns the display, we only add the missing trigger.
#
# Line power is deliberately excluded: that is repowerd's own policy (it sets
# an infinite suspend timeout on line_power), and it keeps the port debuggable
# over the USB gadget.
set -u

# Overridable so the behaviour can be tried out without editing the file.
DELAY=${MAYFLY_SUSPEND_DELAY:-45}
pending=

on_battery() {
    [ "$(cat /sys/class/power_supply/battery/status 2>/dev/null)" = "Discharging" ]
}

cancel() {
    [ -n "$pending" ] || return 0
    kill "$pending" 2>/dev/null
    pending=
}

# A suspend can be refused by a driver that is not ready. Seen here from
# 3da0000.kgsl-smmu ("not prepared for power transition: code -115") when the
# GPU had not settled yet. Without a retry the phone would then stay awake
# until the screen is next switched on and off, which in a pocket is hours --
# exactly the case this exists to avoid. systemctl suspend returns 0 either
# way, so watch the kernel's own counter instead.
try_suspend() {
    i=0
    while [ "$i" -lt 3 ]; do
        before=$(cat /sys/power/suspend_stats/success 2>/dev/null)
        systemctl suspend
        sleep 5
        [ "$(cat /sys/power/suspend_stats/success 2>/dev/null)" != "$before" ] && return 0
        echo "suspend refused ($(cat /sys/power/suspend_stats/last_failed_dev 2>/dev/null)), retrying"
        sleep 25
        i=$((i + 1))
    done
    echo "giving up until the screen is cycled again"
}

# repowerd owns com.canonical.Unity.Screen and emits (state, reason); state 0
# is off. The reason is ignored on purpose -- proximity blanking during a call
# cannot reach here, since repowerd keeps the state at on for that.
gdbus monitor --system --dest com.canonical.Unity.Screen 2>/dev/null |
while read -r line; do
    case "$line" in
    *"DisplayPowerStateChange (0,"*)
        cancel
        if on_battery; then
            ( sleep "$DELAY"; try_suspend ) &
            pending=$!
            echo "screen off on battery, suspending in ${DELAY}s"
        else
            echo "screen off on line power, staying awake"
        fi
        ;;
    *"DisplayPowerStateChange (1,"*)
        cancel
        ;;
    esac
done
