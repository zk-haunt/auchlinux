#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/style.rasi"

options=$'🎞️  Grayscale\n👽  Invert Colors\n🎯  Disable Shaders'

choice="$(printf '%s\n' "$options" | rofi -dmenu -i -no-custom -p "Screen Shaders" -theme "$theme" -theme-str "listview { lines: 3; }")"

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "🎞️  Grayscale")
    hyprctl keyword decoration:screen_shader "$HOME/.config/hypr/shaders/grayscale.frag"
    notify-send -u low "Shaders" "Grayscale applied"
    ;;
  "👽  Invert Colors")
    hyprctl keyword decoration:screen_shader "$HOME/.config/hypr/shaders/invert.frag"
    notify-send -u low "Shaders" "Invert Colors applied"
    ;;
  "🎯  Disable Shaders")
    hyprctl keyword decoration:screen_shader "[[EMPTY]]"
    notify-send -u low "Shaders" "Shaders disabled"
    ;;
esac
