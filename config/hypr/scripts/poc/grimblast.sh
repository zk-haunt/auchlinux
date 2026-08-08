#!/usr/bin/env bash

lockfile="${XDG_RUNTIME_DIR:-/tmp}/grimblast.lock"
[[ -e "$lockfile" ]] && exit 2
touch "$lockfile"
trap 'rm -f "$lockfile"' EXIT

ACTION=$1
SUBJECT=$2
FILE=${3:-"-"}

need() { command -v "$1" &>/dev/null || exit 1; }

need grim
need slurp
need wl-copy
need hyprctl
need jq

[[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]] && exit 1

get_geom_area() { slurp; }
get_geom_active() {
    hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}
get_geom_window() {
    hyprctl clients -j | jq -r '
        .[] |
        select(.mapped == true) |
        "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    ' | slurp
}
get_output() {
    hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name'
}

case "$SUBJECT" in
    area) GEOM=$(get_geom_area) ;;
    active) GEOM=$(get_geom_active) ;;
    window) GEOM=$(get_geom_window) ;;
    output) OUTPUT=$(get_output) ;;
    screen) ;;
    *) exit 1 ;;
esac

run_grim() {
    if [[ -n "$OUTPUT" ]]; then
        grim -o "$OUTPUT" -
    elif [[ -n "$GEOM" ]]; then
        grim -g "$GEOM" -
    else
        grim -
    fi
}

case "$ACTION" in
    copy)     run_grim | wl-copy --type image/png ;;
    save)     run_grim > "$FILE" ;;
    copysave) run_grim | tee "$FILE" | wl-copy --type image/png ;;
    *) exit 1 ;;
esac
