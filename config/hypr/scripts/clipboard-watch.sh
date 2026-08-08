#!/usr/bin/env bash

if ! pgrep -u "$USER" -f "wl-paste.*--type text.*cliphist store" >/dev/null; then
  wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
fi

if ! pgrep -u "$USER" -f "wl-paste.*--type image.*cliphist store" >/dev/null; then
  wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
fi
