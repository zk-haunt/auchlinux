#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/style.rasi"

options=$'🚀  Fast (Minimal)\n🌊  Smooth (Default)\n🍿  Bouncy\n🎯  Instant (Disabled)'

choice="$(printf '%s\n' "$options" | rofi -dmenu -i -no-custom -p "Animations" -theme "$theme" -theme-str "listview { lines: 4; }")"

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "🚀  Fast (Minimal)")
    hyprctl keyword animations:enabled true
    hyprctl keyword bezier "myBezier, 0.05, 0.9, 0.1, 1.05"
    hyprctl keyword animation "windows, 1, 3, myBezier"
    hyprctl keyword animation "windowsOut, 1, 3, default, popin 80%"
    hyprctl keyword animation "border, 1, 5, default"
    hyprctl keyword animation "fade, 1, 3, default"
    hyprctl keyword animation "workspaces, 1, 3, default"
    notify-send -u low "Animations" "Set to Fast"
    ;;
  "🌊  Smooth (Default)")
    hyprctl keyword animations:enabled true
    hyprctl keyword bezier "wind, 0.05, 0.9, 0.1, 1.05"
    hyprctl keyword bezier "winIn, 0.1, 1.1, 0.1, 1.1"
    hyprctl keyword bezier "winOut, 0.3, -0.3, 0, 1"
    hyprctl keyword bezier "liner, 1, 1, 1, 1"
    hyprctl keyword animation "windows, 1, 6, wind, slide"
    hyprctl keyword animation "windowsIn, 1, 6, winIn, slide"
    hyprctl keyword animation "windowsOut, 1, 5, winOut, slide"
    hyprctl keyword animation "windowsMove, 1, 5, wind, slide"
    hyprctl keyword animation "border, 1, 1, liner"
    hyprctl keyword animation "borderangle, 1, 30, liner, loop"
    hyprctl keyword animation "fade, 1, 10, default"
    hyprctl keyword animation "workspaces, 1, 5, wind"
    notify-send -u low "Animations" "Set to Smooth"
    ;;
  "🍿  Bouncy")
    hyprctl keyword animations:enabled true
    hyprctl keyword bezier "overshot, 0.13, 0.99, 0.29, 1.1"
    hyprctl keyword animation "windows, 1, 4, overshot, popin 60%"
    hyprctl keyword animation "windowsOut, 1, 4, default, popin 80%"
    hyprctl keyword animation "border, 1, 10, default"
    hyprctl keyword animation "fade, 1, 10, default"
    hyprctl keyword animation "workspaces, 1, 6, overshot, slidevert"
    notify-send -u low "Animations" "Set to Bouncy"
    ;;
  "🎯  Instant (Disabled)")
    hyprctl keyword animations:enabled false
    notify-send -u low "Animations" "Disabled"
    ;;
esac
