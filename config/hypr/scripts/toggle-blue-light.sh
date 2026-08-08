#!/usr/bin/env bash
# Toggle blue light filter shader on/off

SHADER="$HOME/.config/hypr/shaders/blue-light-filter.frag"
STATE_FILE="/tmp/blue-light-filter.state"

if [[ -f "$STATE_FILE" ]]; then
    # Currently ON — turn off
    hyprctl keyword decoration:screen_shader ""
    rm -f "$STATE_FILE"
    notify-send -i night-light "Blue Light Filter" "Disabled" -t 2000
else
    # Currently OFF — turn on
    hyprctl keyword decoration:screen_shader "$SHADER"
    touch "$STATE_FILE"
    notify-send -i night-light "Blue Light Filter" "Enabled (warm 3000K)" -t 2000
fi
