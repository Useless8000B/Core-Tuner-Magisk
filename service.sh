#!/system/bin/sh
# Core Tuner - Persistence Script

MODDIR=${0%/*}
sleep 15

CONFIG_DIR="/data/core_tuner"

magiskpolicy --live "allow init self capability sys_admin" 2>/dev/null

magiskpolicy --live "type core_tuner_app"
magiskpolicy --live "typeattribute core_tuner_app appdomain"
magiskpolicy --live "permissive core_tuner_app"

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

    if [ -f "$CONFIG_DIR/low_memory_killer" ]; then
        LMK_VAL=$(cat $CONFIG_DIR/low_memory_killer)
        setprop persist.sys.lmk.minfree_levels "$LMK_VAL"
        setprop sys.lmk.minfree_levels "$LMK_VAL"
        killall -HUP lmkd 2>/dev/null
    fi

    if [ -f "$CONFIG_DIR/battery_idle_mode" ]; then
        BATT_IDLE=$(cat $CONFIG_DIR/battery_idle_mode)
        echo "$BATT_IDLE" > /sys/class/power_supply/battery/input_suspend 2>/dev/null
        echo "$BATT_IDLE" > /sys/class/power_supply/battery/charging_enabled 2>/dev/null
    fi 
fi

echo "Core Tuner: Tweaks applied with success at $(date)" >> $CONFIG_DIR/last_boot.log