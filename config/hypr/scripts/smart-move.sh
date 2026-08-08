#!/usr/bin/env bash
# Smart-move the active window. Runs ASYNC (spawned by exec_cmd), so querying
# hyprctl here does NOT deadlock the compositor — unlike doing io.popen inside a
# lua bind handler, which blocks the compositor thread that hyprctl needs.
#
# floating window  -> nudge 30px in <dir> (relative; computed from current pos)
# tiled window     -> move in the layout direction
# Dispatch uses the lua-object form, the only one this lua-Hyprland accepts.
#   usage: smart-move.sh left|right|up|down
dir="$1"
step=30

win=$(hyprctl activewindow -j 2>/dev/null)
[ -z "$win" ] && exit 0

if [ "$(printf '%s' "$win" | jq -r .floating)" = "true" ]; then
    x=$(printf '%s' "$win" | jq -r '.at[0]')
    y=$(printf '%s' "$win" | jq -r '.at[1]')
    case "$dir" in
        left)  x=$((x - step)) ;;
        right) x=$((x + step)) ;;
        up)    y=$((y - step)) ;;
        down)  y=$((y + step)) ;;
    esac
    hyprctl dispatch "hl.dsp.window.move({x=$x,y=$y})" >/dev/null 2>&1
else
    hyprctl dispatch "hl.dsp.window.move({direction=\"$dir\"})" >/dev/null 2>&1
fi
