#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/style.rasi"

if ! command -v playerctl >/dev/null; then
    notify-send -u critical "Media Player" "playerctl is not installed!"
    exit 1
fi

status=$(playerctl status 2>/dev/null)
if [[ -z "$status" ]]; then
    now_playing="No media is playing."
else
    now_playing="$(playerctl metadata --format '{{title}} - {{artist}}' 2>/dev/null)"
fi

options=$'⏮️  Previous\n⏯️  Play / Pause\n⏭️  Next\n⏹️  Stop'

choice="$(printf '%s\n' "$options" | rofi -dmenu -i -no-custom -p "Media Player" -mesg "<b>Now Playing:</b> $now_playing" -theme "$theme" -theme-str "listview { lines: 4; }")"

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "⏮️  Previous")
    playerctl previous
    ;;
  "⏯️  Play / Pause")
    playerctl play-pause
    ;;
  "⏭️  Next")
    playerctl next
    ;;
  "⏹️  Stop")
    playerctl stop
    ;;
esac
