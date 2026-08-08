#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/style.rasi"

options=$'💻  Coding\n🎮  Gaming\n🌐  Browsing'

choice="$(printf '%s\n' "$options" | rofi -dmenu -i -no-custom -p "Select Workflow" -theme "$theme" -theme-str "listview { lines: 3; }")"

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "💻  Coding")
    notify-send -u low "Workflow" "Launching Coding layout..."
    hyprctl dispatch workspace 2
    kitty &
    sleep 0.5
    code &
    ;;
  "🎮  Gaming")
    notify-send -u low "Workflow" "Launching Gaming layout..."
    hyprctl dispatch workspace 5
    steam &
    ;;
  "🌐  Browsing")
    notify-send -u low "Workflow" "Launching Browsing layout..."
    hyprctl dispatch workspace 1
    zen-browser &
    ;;
esac
