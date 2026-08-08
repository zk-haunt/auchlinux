#!/usr/bin/env bash

# Check if waybar is managed by systemd
USE_SYSTEMD=false
if systemctl --user list-units --all -t service | grep -q "waybar.service"; then
    USE_SYSTEMD=true
fi

# Clean up any manually spawned or detached waybars first
killall -q -9 waybar || true
sleep 0.2

if [[ "$USE_SYSTEMD" == true ]]; then
    echo "Restarting Waybar via systemd..."
    systemctl --user reset-failed waybar.service || true
    systemctl --user restart waybar.service
else
    echo "Restarting Waybar manually..."
    waybar &
fi