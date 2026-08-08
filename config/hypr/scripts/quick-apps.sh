#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/style.rasi"

options=$'🌐  Browser (Zen)\n💻  Code (VSCode)\n📝  Notes (Obsidian)\n🎵  Music (Spotify)\n💬  Chat (Discord)'

choice="$(printf '%s\n' "$options" | rofi -dmenu -i -no-custom -p "Quick Apps" -theme "$theme" -theme-str "listview { lines: 5; }")"

[[ -z "$choice" ]] && exit 0

case "$choice" in
  "🌐  Browser (Zen)")
    zen-browser &
    ;;
  "💻  Code (VSCode)")
    code &
    ;;
  "📝  Notes (Obsidian)")
    obsidian &
    ;;
  "🎵  Music (Spotify)")
    spotify &
    ;;
  "💬  Chat (Discord)")
    discord &
    ;;
esac
