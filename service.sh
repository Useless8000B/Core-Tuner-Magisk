#!/system/bin/sh
# Core Tuner - Persistence Script

MODDIR=${0%/*}
sleep 20

CONFIG_DIR="/data/core_tuner"

magiskpolicy --live "allow init self capability sys_admin" 2>/dev/null
magiskpolicy --live "allow priv_app sysfs_zram dir search" 2>/dev/null
magiskpolicy --live "allow priv_app sysfs_zram file { getattr open write }" 2>/dev/null
magiskpolicy --live "allow untrusted_app sysfs_batteryinfo file { getattr open read }" 2>/dev/null
magiskpolicy --live "allow untrusted_app sysfs file { getattr open read }" 2>/dev/null

chmod 644 /sys/class/power_supply/battery/capacity
chmod 644 /sys/class/power_supply/battery/voltage_now
chmod 644 /sys/class/power_supply/battery/current_now

if [ -d "$CONFIG_DIR" ]; then
    if [ -f "$CONFIG_DIR/swappiness" ]; then
        echo "$(cat $CONFIG_DIR/swappiness)" > /proc/sys/vm/swappiness
    fi

    if [ -f "$CONFIG_DIR/vm_dirty_ratio" ]; then
        echo "$(cat $CONFIG_DIR/vm_dirty_ratio)" > /proc/sys/vm/dirty_ratio
    fi

    if [ -f "$CONFIG_DIR/vm_dirty_background_ratio" ]; then
        echo "$(cat $CONFIG_DIR/vm_dirty_background_ratio)" > /proc/sys/vm/dirty_background_ratio
    fi

    if [ -f "$CONFIG_DIR/governor" ]; then
        GOV=$(cat $CONFIG_DIR/governor)
        echo "$GOV" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1
    fi

    if [ -f "$CONFIG_DIR/lmk_minfree" ]; then
        LMK_VAL=$(cat $CONFIG_DIR/lmk_minfree)
        setprop persist.sys.lmk.minfree_levels "$LMK_VAL"
        setprop sys.lmk.minfree_levels "$LMK_VAL"
        killall -HUP lmkd 2>/dev/null
    fi

    if [ -f "$CONFIG_DIR/battery_idle_mode" ]; then
        BATT_IDLE=$(cat $CONFIG_DIR/battery_idle_mode)
        echo "$BATT_IDLE" > /sys/class/power_supply/battery/input_suspend 2>/dev/null
        echo "$BATT_IDLE" > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
    fi

    if [ -f "$CONFIG_DIR/zram_enabled" ] && [ "$(cat $CONFIG_DIR/zram_enabled)" == "1" ]; then
        /system/bin/toybox swapoff /dev/block/zram0 > /dev/null 2>&1
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
        echo 8 > /sys/block/zram0/max_comp_streams 2>/dev/null
        echo 2147483648 > /sys/block/zram0/disksize || echo 1G > /sys/block/zram0/disksize
        /system/bin/toybox mkswap /dev/block/zram0
        /system/bin/toybox swapon /dev/block/zram0 -p 100
        sysctl -w vm.vfs_cache_pressure=100
    fi

    (
        while true; do
            if [ -f "$CONFIG_DIR/charge_limit" ]; then
                LIMIT=$(cat "$CONFIG_DIR/charge_limit")
                LEVEL=$(cat /sys/class/power_supply/battery/capacity)
                IDLE_REQ=$(cat "$CONFIG_DIR/battery_idle_mode" 2>/dev/null || echo "0")

                if [ "$IDLE_REQ" == "1" ]; then
                    echo 1 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
                    echo 0 > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
                else
                    if [ "$LEVEL" -ge "$LIMIT" ]; then
                        echo 1 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
                        echo 0 > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
                    elif [ "$LEVEL" -lt "$((LIMIT - 2))" ]; then
                        echo 0 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
                        echo 1 > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
                    fi
                fi
            fi
            sleep 60
        done
    ) &
fi

echo "Core Tuner: Tweaks applied with success at $(date)" >> $CONFIG_DIR/last_boot.log