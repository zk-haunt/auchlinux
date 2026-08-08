#!/usr/bin/env bash

set -euo pipefail

notify_id="${MEDIA_NOTIFY_ID:-91193}"

has() {
  command -v "$1" >/dev/null 2>&1
}

notify_track() {
  has notify-send || return 0

  local status title artist message icon
  status="$(playerctl status 2>/dev/null || true)"
  title="$(playerctl metadata title 2>/dev/null || true)"
  artist="$(playerctl metadata artist 2>/dev/null || true)"

  case "$status" in
    Playing) icon="" ;;
    Paused) icon="" ;;
    *) icon="" ;;
  esac

  if [[ -n "$title" && -n "$artist" ]]; then
    message="$artist - $title"
  elif [[ -n "$title" ]]; then
    message="$title"
  else
    message="${status:-No active player}"
  fi

  notify-send \
    -a "Media" \
    -r "$notify_id" \
    -u low \
    -t 1200 \
    -e \
    -h "string:x-canonical-private-synchronous:media" \
    -h "string:x-dunst-stack-tag:media" \
    "$icon  Media" "$message"
}

has playerctl || {
  printf 'media.sh: playerctl is required\n' >&2
  exit 1
}

case "${1:-}" in
  next|previous|play-pause|play|pause|stop)
    playerctl "$1" 2>/dev/null || exit 0
    ;;
  *)
    printf 'Usage: %s {next|previous|play-pause|play|pause|stop}\n' "$0" >&2
    exit 1
    ;;
esac

notify_track
