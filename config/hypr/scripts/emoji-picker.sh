#!/usr/bin/env bash

# Toggle: if rofi is already running for the user, kill it and exit
if pgrep -u "$USER" -x rofi >/dev/null; then
  pkill -u "$USER" -x rofi
  exit 0
fi

db_file="$HOME/.config/rofi/emoji.db"
recent_file="$HOME/.cache/rofi_emoji_recent"
theme="$HOME/.config/rofi/clipboard/style.rasi"

if [[ ! -f "$db_file" ]]; then
  notify-send -u low "Emoji Picker" "Database not found: $db_file"
  exit 1
fi

if [[ ! -f "$recent_file" ]]; then
  touch "$recent_file"
fi

# Get selection using Rofi (combining recent and all emojis, preserving order)
selection=$( (cat "$recent_file"; cat "$db_file") | awk '!seen[$0]++' | rofi -dmenu -i -p "🔎 Emoji" -theme "$theme" -theme-str 'entry { placeholder: "Search Emojis..."; }')
[[ -z "$selection" ]] && exit 0

# Extract emoji character (first space-separated token)
emoji=$(echo "$selection" | awk '{print $1}')

if [[ -n "$emoji" ]]; then
  echo "$emoji" | tr -d '\n' | wl-copy
  notify-send -a "Emoji Picker" -i "dialog-information" "Copied to Clipboard" "$emoji"
  
  # Save to recent list (limit to 30 items)
  (echo "$selection"; cat "$recent_file") | awk '!seen[$0]++' | head -n 30 > "${recent_file}.tmp"
  mv "${recent_file}.tmp" "$recent_file"
fi
