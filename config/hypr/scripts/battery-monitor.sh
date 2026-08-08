#!/usr/bin/env bash
# Battery saver daemon (started from hyprland autostart.lua).
# Drives power-profiles-daemon based on battery state:
#   discharging <= 20%  -> switch to power-saver + notify
#   discharging <= 10%  -> critical notification, re-nagged every 5 min
#   back on AC          -> restore balanced (only if we forced power-saver)
# Manual profile choices (waybar module / powerprofilesctl) are left alone
# otherwise.

# Single-instance guard. A pgrep check in the launcher can't work here:
# pgrep -f matches the launcher's own sh -c command line, and pgrep -x never
# matches because the env-shebang makes our comm "bash", not the script name.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/battery-monitor.lock"
flock -n 9 || exit 0

BAT=/sys/class/power_supply/BAT0
INTERVAL=30
LOW=20
CRIT=10

last_state=""
last_warn=0

while sleep "$INTERVAL"; do
    [[ -r $BAT/capacity && -r $BAT/status ]] || continue
    cap=$(<"$BAT/capacity")
    status=$(<"$BAT/status")

    if [[ $status == "Discharging" ]]; then
        if   (( cap <= CRIT )); then state="critical"
        elif (( cap <= LOW  )); then state="low"
        else                         state="battery"
        fi
    else
        state="ac"
    fi

    if [[ $state == "$last_state" ]]; then
        if [[ $state == "critical" ]] && (( $(date +%s) - last_warn >= 300 )); then
            notify-send -u critical "Battery critical: ${cap}%" "Plug in now."
            last_warn=$(date +%s)
        fi
        continue
    fi

    case $state in
        ac)
            if [[ $last_state == "low" || $last_state == "critical" ]]; then
                powerprofilesctl set balanced 2>/dev/null
                notify-send "On AC power" "Restored balanced profile."
            fi
            ;;
        low)
            powerprofilesctl set power-saver 2>/dev/null
            notify-send "Battery ${cap}%" "Switched to power-saver profile."
            ;;
        critical)
            powerprofilesctl set power-saver 2>/dev/null
            notify-send -u critical "Battery critical: ${cap}%" "Plug in now."
            last_warn=$(date +%s)
            ;;
    esac
    last_state=$state
done
