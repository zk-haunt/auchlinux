#!/usr/bin/env bash

set -euo pipefail

step="${BRIGHTNESS_STEP:-5}"           # Step size in percent (no % symbol)
notify_id="${BRIGHTNESS_NOTIFY_ID:-91192}"

has() {
  command -v "$1" >/dev/null 2>&1
}

has brightnessctl || {
  printf 'brightness.sh: brightnessctl is required\n' >&2
  exit 1
}

# ── Internal display brightness ───────────────────────────────
brightness_percent() {
  brightnessctl -m | awk -F, '{ gsub("%", "", $4); print $4 }'
}

# ── External monitor brightness via ddcutil ───────────────────
has_ddcutil() {
  has ddcutil && ddcutil detect --brief 2>/dev/null | grep -q "^Display"
}

ext_brightness_percent() {
  ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}'
}

ext_set_brightness() {
  local val="$1"
  ddcutil setvcp 10 "$val" 2>/dev/null || true
}

ext_change_brightness() {
  local dir="$1"  # "up" or "down"
  local current
  current=$(ext_brightness_percent 2>/dev/null) || return 0
  [[ -z "$current" ]] && return 0

  local new_val
  if [[ "$dir" == "up" ]]; then
    new_val=$(( current + step ))
    if (( new_val > 100 )); then new_val=100; fi
  else
    new_val=$(( current - step ))
    if (( new_val < 0 )); then new_val=0; fi
  fi
  ext_set_brightness "$new_val"
}

# ── Notification ──────────────────────────────────────────────
notify_brightness() {
  has notify-send || return 0
  local brightness="$1"
  notify-send \
    -a "Brightness" \
    -r "$notify_id" \
    -u low \
    -t 900 \
    -e \
    -h "int:value:${brightness}" \
    -h "string:x-canonical-private-synchronous:brightness" \
    -h "string:x-dunst-stack-tag:brightness" \
    "󰃠  Brightness" "${brightness}%"
}

# ── Commands ──────────────────────────────────────────────────
case "${1:-}" in
  up)
    brightnessctl -q -n2 set "${step}%+"
    # Also bump external monitor if connected
    has_ddcutil && ext_change_brightness up
    ;;

  down)
    brightnessctl -q -n2 set "${step}%-"
    # Also dim external monitor if connected
    has_ddcutil && ext_change_brightness down
    ;;

  min)
    brightnessctl -q -n2 set 2%
    has_ddcutil && ext_set_brightness 0
    ;;

  max)
    brightnessctl -q -n2 set 100%
    has_ddcutil && ext_set_brightness 100
    ;;

  *)
    printf 'Usage: %s {up|down|min|max}\n' "$0" >&2
    exit 1
    ;;
esac

notify_brightness "$(brightness_percent)"
