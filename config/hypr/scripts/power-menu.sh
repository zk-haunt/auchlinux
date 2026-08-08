#!/usr/bin/env bash

theme="$HOME/.config/rofi/powermenu/logout.rasi"

options=$'  Lock\n󰐥  Shutdown\n󰜉  Restart\n󰍃  Logout\n󰤄  Suspend'

menu() {
  local prompt="$1"
  local lines="${2:-5}"
  rofi -dmenu -i -no-custom -p "$prompt" -theme "$theme" -theme-str "listview { lines: ${lines}; }"
}

confirm() {
  local action="$1"
  local answer
  answer="$(printf '  Yes\n  No\n' | rofi -dmenu -i -no-custom -p "$action?" -theme "$theme" -theme-str "listview { lines: 2; }")"
  [[ "$answer" == "  Yes" ]]
}

lock_screen() {
  pidof hyprlock > /dev/null || hyprlock
}

choice="$(printf '%s\n' "$options" | menu "System" 5)"
[[ -z "$choice" ]] && exit 0

case "$choice" in
  "  Lock")
    lock_screen
    ;;
  "󰤄  Suspend")
    confirm "Suspend" && loginctl lock-session && systemctl suspend
    ;;
  "󰍃  Logout")
    if confirm "Logout"; then
      if command -v uwsm > /dev/null 2>&1 && uwsm check is-active; then
        uwsm stop
      else
        hyprctl dispatch exit
      fi
    fi
    ;;
  "󰜉  Restart")
    confirm "Restart" && systemctl reboot
    ;;
  "󰐥  Shutdown")
    confirm "Shutdown" && systemctl poweroff
    ;;
  *)
    notify-send -u low "Power menu" "Unknown action: $choice"
    ;;
esac
